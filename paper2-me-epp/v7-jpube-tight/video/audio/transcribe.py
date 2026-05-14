"""Transcribe NotebookLM audio with word-level timestamps via faster-whisper.

Uses CPU (CTranslate2 INT8); ~5–10 min wall time for ~17 min of audio on
the i7-1260P. Outputs `transcript.json` with one entry per segment:

    {
      "start": 12.34, "end": 17.89,
      "text": "...",
      "words": [
        {"start": 12.34, "end": 12.55, "word": "..."},
        ...
      ]
    }

No speaker diarization yet — we tag manually after listening because the
two NotebookLM hosts have distinguishable timbres but pyannote setup is
heavy. For now, downstream code treats the segment list as a single
narration timeline.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys
import time

from faster_whisper import WhisperModel


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("audio", type=pathlib.Path)
    ap.add_argument("--model", default="small.en",
                    help="faster-whisper model size: tiny.en, base.en, "
                         "small.en, medium.en, large-v3")
    ap.add_argument("--out", type=pathlib.Path, default=None)
    ap.add_argument("--compute-type", default="int8")
    args = ap.parse_args()

    out = args.out or args.audio.with_name("transcript.json")
    print(f"Loading model {args.model} (compute_type={args.compute_type})…",
          file=sys.stderr)
    model = WhisperModel(args.model, device="cpu",
                          compute_type=args.compute_type, cpu_threads=12)

    t0 = time.time()
    segments_iter, info = model.transcribe(
        str(args.audio),
        word_timestamps=True,
        vad_filter=True,
        vad_parameters={"min_silence_duration_ms": 300},
        language="en",
        beam_size=5,
        condition_on_previous_text=True,
    )
    print(f"Detected language={info.language} (p={info.language_probability:.2f}); "
          f"audio duration={info.duration:.1f}s", file=sys.stderr)

    out_segments = []
    for seg in segments_iter:
        words = [
            {"start": round(w.start, 3), "end": round(w.end, 3),
             "word": w.word.strip(), "probability": round(w.probability, 3)}
            for w in (seg.words or [])
        ]
        out_segments.append({
            "id": seg.id,
            "start": round(seg.start, 3),
            "end": round(seg.end, 3),
            "text": seg.text.strip(),
            "words": words,
        })
        # progress feedback
        if seg.id % 10 == 0:
            print(f"  segment {seg.id}: t={seg.start:6.1f}s  "
                  f"{seg.text.strip()[:60]}", file=sys.stderr)

    elapsed = time.time() - t0
    print(f"Done in {elapsed:.1f}s ({len(out_segments)} segments).",
          file=sys.stderr)

    out.write_text(json.dumps({
        "audio_path": str(args.audio.resolve()),
        "model": args.model,
        "language": info.language,
        "duration_sec": info.duration,
        "n_segments": len(out_segments),
        "segments": out_segments,
    }, indent=2, ensure_ascii=False))
    print(f"Wrote {out}", file=sys.stderr)


if __name__ == "__main__":
    main()
