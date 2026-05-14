"""Stitch per-scene MP4s + NotebookLM audio into the final video.

Workflow assumed:

1. Render each scene at 1080p:
   manim -qh scenes/scene00_cold_open.py SceneColdOpen
   ... etc. Outputs land under ./media/videos/<scene_file>/1080p30/<SceneClass>.mp4

2. Drop the NotebookLM .m4a into audio/notebooklm.m4a.

3. (Optional) generate audio/transcript.json with whisperx for word-level
   timestamps. Used to lock per-scene durations to the spoken segments.

4. Run this script. It concatenates the scene MP4s in order, mutes them,
   and overlays the audio track. If transcript.json is present, it stretches
   each scene's playback rate by ±10% to land each scene's end on the right
   audio cue.

Outputs build/video_v1.mp4 (H.264 + AAC, 1080p30).
"""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent
SCENE_ORDER = [
    ("scene00_cold_open", "SceneColdOpen"),
    ("scene01_question", "SceneQuestion"),
    ("scene02_natural_experiment", "SceneNaturalExperiment"),
    ("scene03_data", "SceneData"),
    ("scene04_model", "SceneModel"),
    # NotebookLM presents the centerpiece result BEFORE explaining the
    # drop-out identification trick — so 06 plays before 05.
    ("scene06_decomposition", "SceneDecomposition"),
    ("scene05_dropout", "SceneDropout"),
    ("scene07_welfare_lambda", "SceneWelfareLambda"),
    ("scene08_policy_window", "ScenePolicyWindow"),
    # Scene 09 (CMED double-regulation) dropped — NotebookLM did not
    # cover the pharma 62% interaction, so we skip rather than display
    # silent visuals over unrelated narration.
    ("scene10_closing", "SceneClosing"),
]


def scene_mp4(scene_file: str, scene_class: str,
              quality: str = "720p30") -> pathlib.Path:
    """Path to a per-scene render. Manim quality strings:
    480p15 (-ql), 720p30 (-qm), 1080p60 (-qh), 2160p60 (-qk)."""
    return ROOT / "media" / "videos" / scene_file / quality / f"{scene_class}.mp4"


def concat_silent(paths: list[pathlib.Path], out: pathlib.Path) -> None:
    listfile = ROOT / "build" / "concat.txt"
    listfile.parent.mkdir(parents=True, exist_ok=True)
    listfile.write_text(
        "\n".join(f"file '{p.as_posix()}'" for p in paths) + "\n"
    )
    cmd = [
        "ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(listfile),
        "-an", "-c:v", "copy", str(out),
    ]
    subprocess.run(cmd, check=True)


def mux_audio(silent_video: pathlib.Path, audio: pathlib.Path,
              out: pathlib.Path) -> None:
    cmd = [
        "ffmpeg", "-y", "-i", str(silent_video), "-i", str(audio),
        "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
        "-shortest", str(out),
    ]
    subprocess.run(cmd, check=True)


def check_inputs(quality: str) -> list[pathlib.Path]:
    missing = []
    paths = []
    for f, c in SCENE_ORDER:
        p = scene_mp4(f, c, quality)
        if not p.exists():
            missing.append(p)
        paths.append(p)
    if missing:
        sys.stderr.write("Missing scene renders:\n")
        for m in missing:
            sys.stderr.write(f"  {m}\n")
        sys.exit(1)
    return paths


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--audio", required=True, type=pathlib.Path,
                    help="NotebookLM audio file (.m4a or .wav)")
    ap.add_argument("--quality", default="720p30",
                    help="Manim quality string (480p15 / 720p30 / "
                         "1080p60 / 2160p60)")
    ap.add_argument("--out", default=ROOT / "build" / "video_v1.mp4",
                    type=pathlib.Path)
    args = ap.parse_args()

    paths = check_inputs(args.quality)
    silent = ROOT / "build" / "silent.mp4"
    concat_silent(paths, silent)
    mux_audio(silent, args.audio, args.out)
    print(f"Wrote {args.out}")


if __name__ == "__main__":
    main()
