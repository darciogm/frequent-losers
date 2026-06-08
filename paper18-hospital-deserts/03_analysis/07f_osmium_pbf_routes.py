#!/usr/bin/env python3
"""
07f_osmium_pbf_routes — full-Brazil road-network routing using local PBF
extracts (Geofabrik), pyosmium for parsing, networkx for shortest-path.

Strategy:
- Download regional PBFs once into 02_data/raw/osm/.
- For each region: parse PBF -> extract drivable ways -> build networkx graph.
- Route every muni in the region to its nearest high-complexity hub (hubs in
  any region; cross-region routing falls back to haversine-speed-adjusted).
- Persist per-region parquet, idempotent.

Memory budget: per-region peak ~3-6 GB (sudeste worst, ~6-10 GB).
"""
from __future__ import annotations

import argparse, gc, json, logging, sys, time
from pathlib import Path

import networkx as nx
import numpy as np
import osmium
import polars as pl
import psutil
import requests

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
RAW_OSM = ROOT / "02_data" / "raw" / "osm"
LOG_DIR = ROOT / "04_logs"
ROUTES_DIR = INTER / "osrm_routes_per_region"
LOG_FILE = LOG_DIR / "07f_osmium_pbf_routes.log"
PROGRESS = LOG_DIR / "07f_progress.json"

RAW_OSM.mkdir(parents=True, exist_ok=True)
ROUTES_DIR.mkdir(parents=True, exist_ok=True)

GEOFABRIK = "https://download.geofabrik.de/south-america/brazil"

REGION_UFS = {
    "norte":         ["AC", "AP", "AM", "PA", "RO", "RR", "TO"],
    "centro-oeste":  ["DF", "GO", "MS", "MT"],
    "nordeste":      ["AL", "BA", "CE", "MA", "PB", "PE", "PI", "RN", "SE"],
    "sul":           ["PR", "RS", "SC"],
    "sudeste":       ["ES", "MG", "RJ", "SP"],
}

DRIVABLE = {
    "motorway", "trunk", "primary", "secondary", "tertiary",
    "unclassified", "residential",
    "motorway_link", "trunk_link", "primary_link", "secondary_link", "tertiary_link",
    "living_street", "service",
}

# average free-flow speed by road class (km/h)
SPEED_KMH = {
    "motorway": 100, "motorway_link": 80,
    "trunk": 90, "trunk_link": 70,
    "primary": 70, "primary_link": 50,
    "secondary": 55, "secondary_link": 40,
    "tertiary": 45, "tertiary_link": 35,
    "unclassified": 35, "residential": 30, "living_street": 20, "service": 25,
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG_FILE, mode="a"), logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger("07f")


def rss_gb():
    return psutil.Process().memory_info().rss / 1e9


def hav(lat1, lon1, lat2, lon2):
    from math import radians, sin, cos, sqrt, atan2
    la1, lo1, la2, lo2 = map(radians, (lat1, lon1, lat2, lon2))
    dla, dlo = la2 - la1, lo2 - lo1
    a = sin(dla / 2) ** 2 + cos(la1) * cos(la2) * sin(dlo / 2) ** 2
    return 2 * 6371 * atan2(sqrt(a), sqrt(1 - a))


def download_pbf(region: str) -> Path:
    out = RAW_OSM / f"{region}-latest.osm.pbf"
    if out.exists():
        log.info("PBF %s cached: %.0f MB", region, out.stat().st_size / 1e6)
        return out
    url = f"{GEOFABRIK}/{region}-latest.osm.pbf"
    log.info("Downloading %s from %s ...", region, url)
    t0 = time.time()
    with requests.get(url, stream=True, timeout=300) as r:
        r.raise_for_status()
        total = int(r.headers.get("content-length", 0))
        downloaded = 0
        with open(out, "wb") as f:
            for chunk in r.iter_content(chunk_size=8 << 20):
                f.write(chunk)
                downloaded += len(chunk)
                if total and (downloaded // (8 << 20)) % 5 == 0:
                    log.info("  %s: %.0f / %.0f MB",
                             region, downloaded / 1e6, total / 1e6)
    log.info("Downloaded %s: %.0f MB in %.0fs",
             region, out.stat().st_size / 1e6, time.time() - t0)
    return out


class WayLocHandler(osmium.SimpleHandler):
    """Collect node coords + drivable ways."""
    def __init__(self):
        super().__init__()
        self.node_lat: dict[int, float] = {}
        self.node_lon: dict[int, float] = {}
        self.ways: list[tuple[list[int], str]] = []  # (node_ids, highway_class)

    def node(self, n):
        self.node_lat[n.id] = n.location.lat
        self.node_lon[n.id] = n.location.lon

    def way(self, w):
        hw = w.tags.get("highway")
        if hw not in DRIVABLE:
            return
        nodes = [n.ref for n in w.nodes]
        if len(nodes) < 2:
            return
        self.ways.append((nodes, hw))


def build_graph(pbf_path: Path) -> tuple[nx.DiGraph, np.ndarray, np.ndarray, np.ndarray]:
    log.info("parsing %s ...", pbf_path.name)
    t0 = time.time()
    h = WayLocHandler()
    h.apply_file(str(pbf_path), locations=False)
    log.info("  nodes=%d ways=%d  parse=%.0fs  rss=%.1fGB",
             len(h.node_lat), len(h.ways), time.time() - t0, rss_gb())

    G = nx.DiGraph()
    used_ids = set()
    for ids, hw in h.ways:
        speed = SPEED_KMH.get(hw, 30)
        for u, v in zip(ids[:-1], ids[1:]):
            if u not in h.node_lat or v not in h.node_lat:
                continue
            d = hav(h.node_lat[u], h.node_lon[u], h.node_lat[v], h.node_lon[v]) * 1000
            tt = d / 1000 / speed * 60
            G.add_edge(u, v, length=d, time=tt)
            G.add_edge(v, u, length=d, time=tt)
            used_ids.add(u); used_ids.add(v)
    h.ways.clear()
    log.info("  graph G nodes=%d edges=%d  rss=%.1fGB",
             G.number_of_nodes(), G.number_of_edges(), rss_gb())

    used_ids_l = list(used_ids)
    arr_lat = np.fromiter((h.node_lat[i] for i in used_ids_l), dtype=np.float64,
                          count=len(used_ids_l))
    arr_lon = np.fromiter((h.node_lon[i] for i in used_ids_l), dtype=np.float64,
                          count=len(used_ids_l))
    arr_id = np.array(used_ids_l, dtype=np.int64)
    h.node_lat.clear(); h.node_lon.clear()
    log.info("  done build  rss=%.1fGB  total=%.0fs", rss_gb(), time.time() - t0)
    return G, arr_id, arr_lat, arr_lon


def to_xyz(la, lo):
    la_r = np.radians(la); lo_r = np.radians(lo)
    return np.column_stack([np.cos(la_r) * np.cos(lo_r),
                            np.cos(la_r) * np.sin(lo_r),
                            np.sin(la_r)])


def build_kdtree(node_lat, node_lon):
    from scipy.spatial import cKDTree
    return cKDTree(to_xyz(node_lat, node_lon))


def nearest_node_batch(tree, ids_t, lat_q, lon_q):
    _, idx = tree.query(to_xyz(np.atleast_1d(lat_q), np.atleast_1d(lon_q)), k=1)
    return ids_t[idx]


def load_munis_and_hubs():
    div = pl.read_parquet(INTER / "divergence_panel.parquet")
    munis = div.select(["codmun_6", "uf", "lat", "lon"]).unique(subset=["codmun_6"])
    hub = pl.read_parquet(INTER / "hospital_hub_classification.parquet").filter(
        (pl.col("CNES").str.strip_chars() != "") &
        (pl.col("hub_categoria").is_in(
            ["CARDIO", "ONCO", "NEURO", "RENAL", "PERINAT", "TRAUMA_ORTO", "TRANSPLANTE"]
        )) &
        (pl.col("hub_ativo_qualquer_mes"))
    ).select(["CNES", "codmun_6"]).unique()
    master = pl.read_parquet(INTER / "hospital_master.parquet").select(["CNES", "codmun_6_modal"])
    hub = hub.join(master, on="CNES", how="left").rename({"codmun_6_modal": "codmun_6_hosp"})
    hub = hub.with_columns(pl.coalesce(pl.col("codmun_6_hosp"), pl.col("codmun_6")).alias("codmun_6_loc"))
    cent = pl.read_parquet(INTER / "municipios_centroids.parquet").select(["cod_mun_6", "lat", "lon", "uf"])
    hub_cent = hub.join(cent, left_on="codmun_6_loc", right_on="cod_mun_6", how="inner")
    return munis, hub_cent


def haversine_nn(lat_q, lon_q, lat_t, lon_t):
    from scipy.spatial import cKDTree
    def to_xyz(la, lo):
        la_r = np.radians(la); lo_r = np.radians(lo)
        return np.column_stack([np.cos(la_r) * np.cos(lo_r),
                                np.cos(la_r) * np.sin(lo_r),
                                np.sin(la_r)])
    tree = cKDTree(to_xyz(lat_t, lon_t))
    d, idx = tree.query(to_xyz(lat_q, lon_q), k=1)
    return idx


def process_region(region: str, force: bool = False) -> dict:
    out_path = ROUTES_DIR / f"region={region}.parquet"
    if out_path.exists() and not force:
        log.info("region %s cached, skip", region)
        return {"region": region, "status": "skipped"}

    pbf = download_pbf(region)
    munis, hubs = load_munis_and_hubs()
    munis_r = munis.filter(pl.col("uf").is_in(REGION_UFS[region]))
    n = len(munis_r)
    log.info("region %s: %d munis to route", region, n)
    if n == 0:
        return {"region": region, "status": "empty"}

    # nearest hub by haversine across ALL hubs
    hub_lat_all = hubs["lat"].to_numpy()
    hub_lon_all = hubs["lon"].to_numpy()
    hub_uf_all = hubs["uf"].to_list()
    nn_idx = haversine_nn(munis_r["lat"].to_numpy(), munis_r["lon"].to_numpy(),
                          hub_lat_all, hub_lon_all)

    G, node_ids, node_lat, node_lon = build_graph(pbf)
    log.info("  building kdtree once over %d nodes ...", len(node_ids))
    tree = build_kdtree(node_lat, node_lon)
    log.info("  kdtree ready  rss=%.1fGB", rss_gb())

    # batch nearest-node lookup for ALL muni and hub queries up front
    mlat = munis_r["lat"].to_numpy()
    mlon = munis_r["lon"].to_numpy()
    muni_node_ids = nearest_node_batch(tree, node_ids, mlat, mlon)
    # only the unique hubs we'll need
    needed_hub_idxs = sorted({int(i) for i in nn_idx})
    hub_node_for_idx = {}
    for hi in needed_hub_idxs:
        hub_node_for_idx[hi] = int(nearest_node_batch(
            tree, node_ids, hub_lat_all[hi], hub_lon_all[hi])[0])

    out_min = np.full(n, np.nan)
    out_dist = np.full(n, np.nan)
    cross_region = 0
    failed = 0
    t0 = time.time()

    for i in range(n):
        d_idx = int(nn_idx[i])
        h_uf = hub_uf_all[d_idx]
        if h_uf not in REGION_UFS[region]:
            km = hav(mlat[i], mlon[i], hub_lat_all[d_idx], hub_lon_all[d_idx])
            out_dist[i] = km * 1.35
            out_min[i] = km * 1.35 / 50.0 * 60.0
            cross_region += 1
            continue
        mn = int(muni_node_ids[i])
        hn = hub_node_for_idx[d_idx]
        try:
            if mn == hn:
                out_min[i] = 0.0
                out_dist[i] = 0.0
            else:
                d_m = nx.shortest_path_length(G, mn, hn, weight="length")
                tt_m = nx.shortest_path_length(G, mn, hn, weight="time")
                out_min[i] = tt_m
                out_dist[i] = d_m / 1000.0
        except (nx.NetworkXNoPath, nx.NodeNotFound, ValueError, KeyError):
            failed += 1

        if (i + 1) % 50 == 0:
            log.info("  %s %d/%d cross=%d fail=%d rss=%.1fGB elapsed=%.0fs",
                     region, i + 1, n, cross_region, failed, rss_gb(), time.time() - t0)

    df = munis_r.with_columns([
        pl.Series("travel_time_min_osmnx", out_min),
        pl.Series("travel_dist_km_osmnx", out_dist),
        pl.Series("cross_region", np.array([
            hub_uf_all[int(nn_idx[i])] not in REGION_UFS[region] for i in range(n)
        ])),
    ])
    df.write_parquet(out_path, compression="snappy")
    log.info("region %s done: ok=%d cross=%d fail=%d wall=%.0fs",
             region, n - failed - cross_region, cross_region, failed, time.time() - t0)

    del G, node_ids, node_lat, node_lon
    gc.collect()
    return {"region": region, "n": n, "ok": n - failed - cross_region,
            "cross_region": cross_region, "fail": failed,
            "wall_s": time.time() - t0, "rss_peak_gb": rss_gb()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--regions", default=None,
                    help="comma-separated regions (default: light->heavy order)")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    log.info("==== 07f osmium PBF routes ====")
    log.info("ram_avail=%.1fGB cores=%d", psutil.virtual_memory().available / 1e9,
             psutil.cpu_count())

    if args.regions:
        regions = [r.strip() for r in args.regions.split(",") if r.strip()]
    else:
        regions = ["norte", "centro-oeste", "sul", "nordeste", "sudeste"]
    log.info("regions: %s", regions)

    summary = {}
    for k, region in enumerate(regions):
        log.info("[%d/%d] region %s start  rss=%.1fGB", k + 1, len(regions), region, rss_gb())
        try:
            r = process_region(region, force=args.force)
            summary[region] = r
        except Exception as e:
            log.exception("region %s exception: %s", region, e)
            summary[region] = {"region": region, "status": "exception", "error": str(e)}
        PROGRESS.write_text(json.dumps({
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
            "summary": summary,
        }, indent=2))

    log.info("==== all regions done ====")


if __name__ == "__main__":
    main()
