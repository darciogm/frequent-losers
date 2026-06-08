"""
28d_classify_with_web.py

Etapa 4 do R1: re-classificar todos os closures usando claude-sonnet-4-6
COM os snippets de WebSearch como contexto adicional, quando disponíveis.

Para closures sem snippet web, usa apenas metadata Receita (igual ao 28).

Anti-hallucination reforçado:
- Se snippet existe e contradiz metadata, prevalece o snippet (evidência empírica)
- Se snippet não existe, modelo deve ser conservador (confidence ≤ 3 a não ser
  que metadata inequívoca como BAIXADA + INAPTA + ratio_pre baixo)
- "evidence_flags" deve incluir TODAS as fontes usadas (situacao=BAIXADA,
  web_source: <URL>, etc).

Outputs:
- 02_data/intermediate/closures_classified_v2.parquet (final)
- 04_logs/28d_token_usage.json
- 02_data/intermediate/llm_classify_cache_v2.sqlite (cache)
"""

from __future__ import annotations

import argparse
import hashlib
import json
import logging
import os
import re
import sqlite3
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import polars as pl

ROOT = Path(__file__).resolve().parents[1]
INTER = ROOT / "02_data" / "intermediate"
LOG = ROOT / "04_logs"
SNIPPETS = INTER / "web_snippets"
CACHE = INTER / "llm_classify_cache_v2.sqlite"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "28d_classify_with_web.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("classify_v2")

IN_FILE = INTER / "closures_metadata_with_cnpj.parquet"
OUT_FILE = INTER / "closures_classified_v2.parquet"

MODEL = "claude-sonnet-4-6"

SYSTEM_PROMPT = """You are a Brazilian health-system researcher classifying the
declared / inferred reason for hospital closures in the SUS network.

You receive structured metadata and (when available) web-search snippets
specifically retrieved for this closure. Web snippets are the primary
evidence; metadata corroborates or fills gaps.

CATEGORIES (single-pick):
- administrativo : descredenciamento SUS, intervenção MS, mudança de gestão,
                   reforma psiquiátrica (Lei 10.216/2001), interdição VISA,
                   transferência para gestão pública municipal/estadual
- fiscal         : irregularidade fiscal/regulatória, CNPJ INAPTA, suspensão
                   de credenciamento por compliance Receita Federal
- falencia       : falência declarada, dissolução do CNPJ (BAIXADA),
                   liquidação por insolvência privada
- fusao          : aquisição/incorporação por outra entidade que abriu novo CNES
                   no mesmo município
- demanda        : queda genuína da demanda local (município com retração
                   demográfica, abertura de hospital concorrente próximo)
- pandemia       : fechamento explicitamente vinculado à pandemia 2020-2021
- outros         : causa identificada que não cabe (incêndio, desastre)
- unknown        : informação insuficiente para classificar

ANTI-HALLUCINATION INSTRUCTIONS (mandatory):
- USE the web snippet when available. If it contradicts metadata (e.g.
  Receita ATIVA but snippet documents fechamento real), trust the snippet.
- DO NOT fabricate facts not present in metadata or snippets.
- If snippet is missing AND metadata insufficient, return motivo=unknown
  with confidence ≤ 2.
- Specific patterns:
  * "Reforma Psiquiátrica" / "Lei 10.216" / desinstitucionalização → administrativo (conf 5)
  * "descredenciamento SUS" / "interdição VISA" → administrativo (conf 4-5)
  * "valor SUS sem reajuste / estrangulamento financeiro" → administrativo (conf 4-5)
    [observação: é insolvência por política federal, não demanda local]
  * "CNPJ BAIXADA" sem snippet → falencia (conf 4)
  * "CNPJ INAPTA" sem snippet → fiscal (conf 3-4)
  * "CNPJ ATIVA" + sem snippet de fechamento → unknown ou fusao (conf 1-3)
  * year_closure ∈ {2020, 2021} sem snippet → conservador, unknown (conf 1-2)

OUTPUT FORMAT (strict JSON, no markdown):
{
  "motivo": "<categoria>",
  "confidence": <int 1-5>,
  "reasoning": "<português, 2-3 frases citando evidências usadas>",
  "evidence_flags": ["<flag1>", "<flag2>", ...],
  "web_source_used": <bool>
}
"""


def init_cache():
    con = sqlite3.connect(CACHE)
    con.execute("""
        CREATE TABLE IF NOT EXISTS llm_v2 (
            cache_key TEXT PRIMARY KEY,
            cnes TEXT,
            timestamp_utc TEXT,
            model_id TEXT,
            payload_json TEXT
        )
    """)
    con.commit()
    return con


def cache_key(cnes, year, model, prompt_text):
    h = hashlib.sha256()
    h.update(model.encode()); h.update(b"|"); h.update(prompt_text.encode("utf-8"))
    return f"{cnes}_{year}_{h.hexdigest()[:16]}"


def cache_get(con, key):
    cur = con.execute("SELECT payload_json FROM llm_v2 WHERE cache_key = ?", (key,))
    r = cur.fetchone()
    return json.loads(r[0]) if r else None


def cache_put(con, key, cnes, model, payload):
    con.execute(
        "INSERT OR REPLACE INTO llm_v2 (cache_key, cnes, timestamp_utc, model_id, payload_json) VALUES (?, ?, ?, ?, ?)",
        (key, cnes, datetime.now(timezone.utc).isoformat(), model, json.dumps(payload))
    )
    con.commit()


def load_snippet(cnes):
    """Read web_snippet for CNES if exists. Returns formatted text block or None."""
    paths = list(SNIPPETS.glob(f"{cnes}_*.json"))
    if not paths:
        return None
    parts = []
    for p in sorted(paths):
        with open(p) as f:
            d = json.load(f)
        parts.append(
            f"[Query rank={d.get('query_rank', '?')}] "
            f"key_finding: {d.get('key_finding', '')}\n"
            f"  implied_motive (researcher annotation): {d.get('implied_motive', '?')} "
            f"(conf {d.get('implied_confidence', '?')})\n"
            f"  top URLs: {', '.join(d.get('top_urls', [])[:3])}"
        )
    return "\n\n".join(parts)


def build_user_prompt(rec, web_snippet) -> str:
    lines = [
        "Classifique o motivo do fechamento deste hospital.",
        "",
        "## Metadata estrutural",
        f"  CNES: {rec.get('CNES')}",
        f"  ano de fechamento: {rec.get('year_closure')}",
        f"  município: {rec.get('codmun_hosp_name')} / {rec.get('uf')}",
        f"  tp_unid: {rec.get('tp_unid')} ({'hospital geral' if rec.get('tp_unid')=='05' else 'hospital especializado' if rec.get('tp_unid')=='07' else 'hospital-dia/outro'})",
        f"  qt_sus_pre (leitos SUS no ano pré): {rec.get('qt_sus_pre')}",
        f"  AIH no ano pré-fechamento: {rec.get('n_int_t_minus_1')}",
        f"  ratio_pre (AIH t-1 / média t-3..t-2): {rec.get('ratio_pre')}",
        f"  status do filtro estatístico: {rec.get('status')}",
        "",
        "## Dados Receita Federal (BrasilAPI)",
        f"  razão social: {rec.get('razao_social') or '— não disponível —'}",
        f"  nome fantasia: {rec.get('nome_fantasia') or '— não disponível —'}",
        f"  CNAE: {rec.get('cnae_descr') or '—'}",
        f"  situação cadastral: {rec.get('situacao_cadastral') or '—'}",
        f"  motivo da situação: {rec.get('motivo_situacao') or '—'}",
        f"  data da situação: {rec.get('data_situacao') or '—'}",
        "",
        "## Evidência de WebSearch",
    ]
    if web_snippet:
        lines.append(web_snippet)
    else:
        lines.append("(sem snippet web disponível para este CNES — classifique apenas com metadata, conservadoramente)")
    lines.append("")
    lines.append("Retorne APENAS o JSON conforme o formato do system prompt.")
    return "\n".join(lines)


def parse_response(text):
    t = re.sub(r"^```(?:json)?\s*", "", text.strip())
    t = re.sub(r"\s*```$", "", t)
    try:
        return json.loads(t)
    except Exception:
        m = re.search(r"\{.*\}", t, re.DOTALL)
        if m:
            try: return json.loads(m.group(0))
            except: return None
    return None


def call_anthropic(client, model, system, user, max_tokens=600):
    msg = client.messages.create(
        model=model,
        max_tokens=max_tokens,
        system=[{"type": "text", "text": system,
                 "cache_control": {"type": "ephemeral"}}],
        messages=[{"role": "user", "content": user}],
    )
    text = msg.content[0].text if msg.content else ""
    usage = msg.usage
    return text, {
        "input_tokens": getattr(usage, "input_tokens", None),
        "cache_creation_input_tokens": getattr(usage, "cache_creation_input_tokens", None),
        "cache_read_input_tokens":     getattr(usage, "cache_read_input_tokens", None),
        "output_tokens": getattr(usage, "output_tokens", None),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--limit", type=int, default=None)
    args = ap.parse_args()

    if not os.environ.get("ANTHROPIC_API_KEY"):
        log.error("ANTHROPIC_API_KEY não setado.")
        sys.exit(1)

    t0 = time.time()
    log.info("==== begin v2 classification (Sonnet + Web snippets) ====")
    log.info("model: %s", MODEL)

    df_in = pl.read_parquet(IN_FILE)
    if args.limit:
        df_in = df_in.head(args.limit)
    log.info("closures alvo: %d", len(df_in))

    cache_con = init_cache()
    import anthropic
    client = anthropic.Anthropic()

    rows_out = []
    n_called = n_cached = n_failed = 0
    n_with_snippet = 0
    total_in = total_out = total_cache_read = 0

    for i, r in enumerate(df_in.iter_rows(named=True)):
        rec = dict(r)
        snippet = load_snippet(rec["CNES"])
        if snippet:
            n_with_snippet += 1
        user_prompt = build_user_prompt(rec, snippet)
        key = cache_key(rec["CNES"], rec["year_closure"], MODEL, user_prompt)

        cached = cache_get(cache_con, key)
        if cached and not args.force:
            n_cached += 1
            classification = cached["classification"]
            usage = cached.get("usage", {})
        else:
            try:
                text, usage = call_anthropic(client, MODEL, SYSTEM_PROMPT, user_prompt)
                parsed = parse_response(text)
                if parsed is None:
                    log.warning("[%d] parse fail CNES %s", i + 1, rec["CNES"])
                    classification = {"motivo": "unknown", "confidence": 1,
                                      "reasoning": "parse failure",
                                      "evidence_flags": [], "web_source_used": False,
                                      "raw": text}
                    n_failed += 1
                else:
                    classification = parsed
                cache_put(cache_con, key, rec["CNES"], MODEL,
                          {"classification": classification, "usage": usage})
                n_called += 1
                total_in += usage.get("input_tokens") or 0
                total_out += usage.get("output_tokens") or 0
                total_cache_read += usage.get("cache_read_input_tokens") or 0
                log.info("[%d/%d] %s | snip=%s | motivo=%s conf=%s in=%d out=%d cr=%d",
                         i + 1, len(df_in), rec["CNES"],
                         "yes" if snippet else "no",
                         classification.get("motivo"),
                         classification.get("confidence"),
                         usage.get("input_tokens") or 0,
                         usage.get("output_tokens") or 0,
                         usage.get("cache_read_input_tokens") or 0)
            except Exception as e:
                log.error("[%d/%d] API err CNES %s: %s", i + 1, len(df_in), rec["CNES"], e)
                classification = {"motivo": "unknown", "confidence": 1,
                                  "reasoning": f"api_error: {e}",
                                  "evidence_flags": [], "web_source_used": False}
                n_failed += 1

        rec.update({
            "motivo_v2": classification.get("motivo"),
            "confidence_v2": classification.get("confidence"),
            "reasoning_v2": classification.get("reasoning"),
            "evidence_flags_v2": json.dumps(classification.get("evidence_flags") or []),
            "web_source_used": classification.get("web_source_used", bool(snippet)),
            "model_id_v2": MODEL,
            "snippet_available": bool(snippet),
            "llm_timestamp_v2": datetime.now(timezone.utc).isoformat(),
        })
        rows_out.append(rec)

    log.info("API calls: %d  cached: %d  failed: %d  with_snippet: %d/%d",
             n_called, n_cached, n_failed, n_with_snippet, len(df_in))
    log.info("tokens: in=%d  out=%d  cache_read=%d", total_in, total_out, total_cache_read)

    df_out = pl.DataFrame(rows_out)
    df_out.write_parquet(OUT_FILE, compression="snappy")
    log.info("wrote %s", OUT_FILE)

    # ---- summaries ----
    log.info("\n=== motivo_v2 × tp_unid ===")
    log.info("\n%s", df_out.group_by(["motivo_v2", "tp_unid"])
             .agg([pl.len().alias("n"),
                   pl.col("confidence_v2").mean().alias("conf"),
                   pl.col("snippet_available").sum().alias("n_with_snippet")])
             .sort(["motivo_v2", "tp_unid"]))

    log.info("\n=== motivo_v2 × status ===")
    log.info("\n%s", df_out.group_by(["motivo_v2", "status"])
             .agg(pl.len().alias("n")).sort(["motivo_v2", "status"]))

    log.info("\n=== confidence v1 (haiku) vs v2 (sonnet+web) ===")
    log.info("\n%s", df_out.group_by(["confidence", "confidence_v2"])
             .agg(pl.len().alias("n"))
             .sort(["confidence", "confidence_v2"]))

    log.info("\n=== motivo: v1 → v2 transitions ===")
    log.info("\n%s", df_out.group_by(["motivo", "motivo_v2"])
             .agg(pl.len().alias("n"))
             .sort(["motivo", "motivo_v2"]))

    log.info("\n=== F6 candidates: motivo_v2 ∈ {admin, fiscal, falencia} ===")
    f6 = df_out.filter(pl.col("motivo_v2").is_in(["administrativo", "fiscal", "falencia"]))
    log.info("F6 candidates: %d (status survivor: %d, recovery: %d)",
             len(f6),
             f6.filter(pl.col("status") == "F5_survivor").height,
             f6.filter(pl.col("status") == "F5_recovery_candidate").height)

    f6_strict = df_out.filter(pl.col("motivo_v2").is_in(["administrativo", "fiscal", "falencia"])
                              & (pl.col("confidence_v2") >= 3))
    log.info("F6 strict (conf≥3): %d", len(f6_strict))

    log.info("==== done ==== elapsed %.1fs", time.time() - t0)


if __name__ == "__main__":
    main()
