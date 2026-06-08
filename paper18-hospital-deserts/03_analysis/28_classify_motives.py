"""
28_classify_motives.py

Etapa 3 do R1: classificação NLP zero-shot do motivo de fechamento de cada
closure-alvo, usando Claude (claude-haiku-4-5-20251001) via Anthropic SDK.

Insumos por closure (do output do 27):
- razao_social, nome_fantasia
- codmun_hosp_name, uf
- year_closure
- tp_unid (geral=05, especializado=07)
- situacao_cadastral (ATIVA, BAIXADA, INAPTA)
- motivo_situacao (campo Receita)
- ratio_pre (queda de demanda nos 12 meses anteriores)
- status (F5_survivor vs F5_recovery_candidate)

Prompt instrui o modelo a classificar em uma de:
- administrativo  : descredenciamento SUS, intervenção do Ministério da Saúde, mudança de gestão
- fiscal          : problema fiscal/regulatório (CNPJ INAPTA, Receita Federal)
- falencia        : falência declarada, dissolução, BAIXADA da Receita
- fusao           : fusão/aquisição/migração para CNES novo
- demanda         : queda real de demanda local (mais raro do que F5 sugere)
- pandemia        : fechamento durante 2020-2021 vinculado à pandemia
- outros          : outra causa identificável (incêndio, desastre, etc.)
- unknown         : informação insuficiente para classificar

O modelo retorna JSON estruturado com:
- motivo (string)
- confidence (1-5; 5 = certeza alta)
- reasoning (curto)
- evidence_flags (quais sinais usou: situacao=BAIXADA, fantasia="hospital", etc.)

Anti-hallucination:
- O prompt diz explicitamente: NÃO inventar fatos. Se a evidência não chega,
  motivo = unknown, confidence = 1-2.
- Cada output salvo com timestamp e ID exato do modelo.
- ~10-20% da amostra vai para validação manual (Cohen κ) em etapa 4.

Cache: sqlite. Chave = (CNES, year_closure, model_version, prompt_hash).

Output: 02_data/intermediate/closures_classified.parquet
  schema: + motivo, confidence, reasoning, evidence_flags, model_id,
            llm_timestamp
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
CACHE = INTER / "llm_classify_cache.sqlite"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG / "28_classify_motives.log", mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("classify")

IN_FILE = INTER / "closures_metadata_with_cnpj.parquet"
OUT_FILE = INTER / "closures_classified.parquet"

MODEL_HAIKU = "claude-haiku-4-5-20251001"
MODEL_SONNET = "claude-sonnet-4-6"

SYSTEM_PROMPT = """You are a Brazilian health-system researcher classifying the
declared / inferred reason for hospital closures in the SUS network. You will
receive structured metadata about a single hospital closure and must classify
the motive into one of the categories below, returning a strict JSON object.

CATEGORIES (single-pick):
- administrativo : descredenciamento pelo MS / intervenção administrativa / mudança de gestão / fusão administrativa entre entes públicos
- fiscal         : irregularidade fiscal/regulatória, CNPJ INAPTA na Receita Federal, suspensão de credenciamento por compliance
- falencia       : falência declarada, dissolução do CNPJ (BAIXADA), liquidação
- fusao          : aquisição/incorporação por outra entidade que abriu novo CNES
- demanda        : queda genuína da demanda local (município com retração demográfica, abertura de hospital concorrente próximo etc.)
- pandemia       : fechamento em 2020 ou 2021 com sinais explícitos de causa pandêmica (raro)
- outros         : causa identificada que não cabe nas categorias acima (incêndio, desastre, transferência regional)
- unknown        : informação insuficiente para classificar com mínimo de segurança

ANTI-HALLUCINATION INSTRUCTIONS (mandatory):
- DO NOT invent facts beyond what the input contains. Treat the metadata as
  the only evidence. You are not allowed to assume motivations from name
  patterns alone.
- If the metadata does not allow you to discriminate among categories,
  classify as "unknown" with confidence ≤ 2.
- Confidence is integer 1-5:
    1 = pure guess
    2 = weak signal (one ambiguous flag)
    3 = moderate (multiple consistent signals)
    4 = strong (clear evidence in metadata)
    5 = essentially deterministic (e.g., BAIXADA + INAPTA + queda de demanda)
- "evidence_flags": list of short strings naming the signals you used.
  Examples: "situacao=BAIXADA", "fantasia=hospital especializado",
  "ratio_pre=0.2 (queda forte)", "year=2021 (pandemia)".

REASONING GUIDELINES:
- BAIXADA + INAPTA + ratio_pre baixo -> tendency toward "falencia" or "fiscal"
- ATIVA com queda forte (ratio_pre < 0.5) -> "demanda" só se nenhum outro sinal,
  caso contrário "administrativo" (CNPJ matriz mantida, filial fechou)
- ATIVA, fantasia ausente, sem outros sinais -> "unknown"
- year_closure ∈ {2020, 2021} sem outro sinal -> "pandemia" com confiança 2-3
- Hospital tp_unid=05 (geral) com BAIXADA + ratio < 0.5 -> "falencia" comumente
- Hospital tp_unid=07 (especializado) com situação ATIVA -> tende a "administrativo"
  (descredenciamento da habilitação especializada sem fechar o CNPJ)

OUTPUT FORMAT (strict JSON, no markdown):
{
  "motivo": "<categoria>",
  "confidence": <int 1-5>,
  "reasoning": "<português, 1-3 frases>",
  "evidence_flags": ["<flag1>", "<flag2>", ...]
}
"""


def init_cache():
    con = sqlite3.connect(CACHE)
    con.execute("""
        CREATE TABLE IF NOT EXISTS llm_cache (
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
    h.update(model.encode())
    h.update(b"|")
    h.update(prompt_text.encode("utf-8"))
    return f"{cnes}_{year}_{h.hexdigest()[:16]}"


def cache_get(con, key):
    cur = con.execute("SELECT payload_json FROM llm_cache WHERE cache_key = ?", (key,))
    r = cur.fetchone()
    return json.loads(r[0]) if r else None


def cache_put(con, key, cnes, model, payload):
    con.execute(
        "INSERT OR REPLACE INTO llm_cache (cache_key, cnes, timestamp_utc, model_id, payload_json) VALUES (?, ?, ?, ?, ?)",
        (key, cnes, datetime.now(timezone.utc).isoformat(), model, json.dumps(payload))
    )
    con.commit()


def build_user_prompt(rec) -> str:
    """Constrói o user message com os dados do closure."""
    lines = [
        "Classifique o motivo do fechamento deste hospital:",
        "",
        f"  CNES: {rec.get('CNES')}",
        f"  ano de fechamento: {rec.get('year_closure')}",
        f"  município: {rec.get('codmun_hosp_name')} / {rec.get('uf')}",
        f"  tp_unid: {rec.get('tp_unid')} ({'hospital geral' if rec.get('tp_unid')=='05' else 'hospital especializado' if rec.get('tp_unid')=='07' else 'hospital-dia / outro'})",
        f"  qt_sus_pre (leitos SUS no ano pré): {rec.get('qt_sus_pre')}",
        f"  AIH no ano pré-fechamento: {rec.get('n_int_t_minus_1')}",
        f"  ratio_pre (AIH t-1 / média t-3..t-2): {rec.get('ratio_pre')}",
        f"  status no nosso filtro: {rec.get('status')}",
        "",
        "Dados Receita Federal (BrasilAPI):",
        f"  razão social: {rec.get('razao_social') or 'NÃO DISPONÍVEL'}",
        f"  nome fantasia: {rec.get('nome_fantasia') or 'NÃO DISPONÍVEL'}",
        f"  CNAE: {rec.get('cnae_descr') or 'NÃO DISPONÍVEL'}",
        f"  situação cadastral: {rec.get('situacao_cadastral') or 'NÃO DISPONÍVEL'}",
        f"  motivo da situação cadastral: {rec.get('motivo_situacao') or '--'}",
        f"  data da situação: {rec.get('data_situacao') or '--'}",
        "",
        "Retorne APENAS o JSON conforme o formato especificado."
    ]
    return "\n".join(lines)


def parse_response(text: str) -> dict | None:
    """Extrai JSON da resposta do modelo (tolerante a markdown wrapping)."""
    # remove markdown code fences
    t = re.sub(r"^```(?:json)?\s*", "", text.strip())
    t = re.sub(r"\s*```$", "", t)
    try:
        return json.loads(t)
    except Exception:
        # tentar achar primeiro {…} balanceado
        m = re.search(r"\{.*\}", t, re.DOTALL)
        if m:
            try:
                return json.loads(m.group(0))
            except Exception:
                return None
        return None


def call_anthropic(client, model, system, user, max_tokens=400):
    msg = client.messages.create(
        model=model,
        max_tokens=max_tokens,
        system=[
            {
                "type": "text",
                "text": system,
                "cache_control": {"type": "ephemeral"}  # prompt caching
            }
        ],
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
    ap.add_argument("--force", action="store_true",
                    help="ignora cache; reclassifica tudo")
    ap.add_argument("--dry-run", action="store_true",
                    help="mostra prompts sem chamar API")
    ap.add_argument("--upgrade-low-confidence", action="store_true",
                    help="re-roda casos com confidence ≤ 2 no Sonnet")
    ap.add_argument("--limit", type=int, default=None,
                    help="processar só os primeiros N (debug)")
    args = ap.parse_args()

    if not os.environ.get("ANTHROPIC_API_KEY"):
        log.error("ANTHROPIC_API_KEY não está no environment.")
        sys.exit(1)

    t0 = time.time()
    log.info("==== begin LLM classification ====")
    log.info("model: %s  dry_run=%s", MODEL_HAIKU, args.dry_run)

    df_in = pl.read_parquet(IN_FILE)
    log.info("closures alvo: %d", len(df_in))
    if args.limit:
        df_in = df_in.head(args.limit)
        log.info("LIMIT ativo: processando %d", len(df_in))

    cache_con = init_cache()
    client = None
    if not args.dry_run:
        import anthropic
        client = anthropic.Anthropic()

    rows_out = []
    n_cached = 0
    n_called = 0
    n_failed = 0
    total_in_tok = 0
    total_out_tok = 0
    total_cache_read = 0

    for i, r in enumerate(df_in.iter_rows(named=True)):
        rec = dict(r)
        user_prompt = build_user_prompt(rec)
        key = cache_key(rec["CNES"], rec["year_closure"], MODEL_HAIKU, user_prompt)

        cached = cache_get(cache_con, key)
        if cached and not args.force:
            n_cached += 1
            classification = cached["classification"]
            usage = cached.get("usage") or {}
            log.debug("[%d/%d] cached %s", i + 1, len(df_in), rec["CNES"])
        elif args.dry_run:
            log.info("\n--- dry-run prompt for CNES %s ---\n%s\n", rec["CNES"], user_prompt[:600])
            classification = {"motivo": "DRY_RUN", "confidence": 0, "reasoning": "",
                              "evidence_flags": []}
            usage = {}
        else:
            try:
                text, usage = call_anthropic(client, MODEL_HAIKU, SYSTEM_PROMPT, user_prompt)
                parsed = parse_response(text)
                if parsed is None:
                    log.warning("[%d/%d] parse fail CNES %s; raw=%s",
                                i + 1, len(df_in), rec["CNES"], text[:200])
                    classification = {"motivo": "unknown", "confidence": 1,
                                      "reasoning": "parse failure",
                                      "evidence_flags": [], "raw": text}
                    n_failed += 1
                else:
                    classification = parsed
                cache_put(cache_con, key, rec["CNES"], MODEL_HAIKU,
                          {"classification": classification, "usage": usage,
                           "raw_text": text})
                n_called += 1
                total_in_tok += usage.get("input_tokens") or 0
                total_out_tok += usage.get("output_tokens") or 0
                total_cache_read += usage.get("cache_read_input_tokens") or 0
                log.info("[%d/%d] CNES=%s  motivo=%s  conf=%s  in=%d out=%d cache_read=%d",
                         i + 1, len(df_in), rec["CNES"],
                         classification.get("motivo"),
                         classification.get("confidence"),
                         usage.get("input_tokens") or 0,
                         usage.get("output_tokens") or 0,
                         usage.get("cache_read_input_tokens") or 0)
            except Exception as e:
                log.error("[%d/%d] API error CNES %s: %s",
                          i + 1, len(df_in), rec["CNES"], e)
                classification = {"motivo": "unknown", "confidence": 1,
                                  "reasoning": f"api_error: {e}",
                                  "evidence_flags": []}
                n_failed += 1

        rec.update({
            "motivo": classification.get("motivo"),
            "confidence": classification.get("confidence"),
            "reasoning": classification.get("reasoning"),
            "evidence_flags": json.dumps(classification.get("evidence_flags") or []),
            "model_id": MODEL_HAIKU,
            "llm_timestamp": datetime.now(timezone.utc).isoformat(),
        })
        rows_out.append(rec)

    log.info("API calls: %d  cached: %d  failed: %d", n_called, n_cached, n_failed)
    log.info("tokens: in=%d  out=%d  cache_read=%d",
             total_in_tok, total_out_tok, total_cache_read)

    df_out = pl.DataFrame(rows_out)
    df_out.write_parquet(OUT_FILE, compression="snappy")
    log.info("wrote %s (rows=%d)", OUT_FILE, len(df_out))

    log.info("\n=== distribuição motivo × tp_unid (todos) ===")
    log.info("\n%s", df_out.group_by(["motivo", "tp_unid"])
             .agg([pl.len().alias("n"),
                   pl.col("confidence").mean().alias("conf_mean")])
             .sort(["motivo", "tp_unid"]))

    log.info("\n=== distribuição motivo × status ===")
    log.info("\n%s", df_out.group_by(["motivo", "status"])
             .agg(pl.len().alias("n"))
             .sort(["motivo", "status"]))

    log.info("\n=== confidence distribution ===")
    log.info("\n%s", df_out.group_by("confidence").agg(pl.len().alias("n"))
             .sort("confidence"))

    log.info("==== done ==== elapsed %.1fs", time.time() - t0)


if __name__ == "__main__":
    main()
