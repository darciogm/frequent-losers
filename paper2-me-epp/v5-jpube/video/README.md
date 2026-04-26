# Video — The Cost of Inclusion (paper v5)

Manim Community-based explainer video, ~10 min, English narration via NotebookLM, palette and typography aligned with the paper.

## Layout

```
video/
├── theme.py                 # palette, fonts, helpers, persistent header
├── scenes/                  # one file per scene (Scene00 … Scene10)
├── assets/                  # data (csv/json) sourced from output/tables/*.tex
├── audio/                   # NotebookLM .m4a + word-level transcript JSON
├── build/                   # Manim renders (per-scene MP4)
└── render.py                # stitches per-scene MP4s and final audio mux
```

## One-time setup

Manim CE pulls Cairo, Pango, ffmpeg, and a TeX stack (we already have TinyTeX). On WSL2:

```bash
sudo apt-get install -y libcairo2-dev libpango1.0-dev ffmpeg
python3 -m venv /home/darciogm1/.venvs/manim
/home/darciogm1/.venvs/manim/bin/pip install --upgrade pip
/home/darciogm1/.venvs/manim/bin/pip install manim
```

## Render commands

```bash
# single scene, low-quality preview (480p, 15fps)
/home/darciogm1/.venvs/manim/bin/manim -ql scenes/scene06_decomposition.py SceneDecomposition

# final scene render (1080p, 30fps)
/home/darciogm1/.venvs/manim/bin/manim -qh scenes/scene06_decomposition.py SceneDecomposition

# stitch + audio mux (after all scene MP4s exist)
python3 render.py --audio audio/notebooklm.m4a --transcript audio/transcript.json --out build/video_v1.mp4
```

## Scene index (timings approximate, will lock to NotebookLM transcript)

| #  | File                              | Title                        | Target dur. |
|----|-----------------------------------|------------------------------|-------------|
| 00 | scene00_cold_open.py              | R$ 50–85 million             | 25 s        |
| 01 | scene01_question.py               | The question                 | 45 s        |
| 02 | scene02_natural_experiment.py     | March 2018 reinterpretation  | 60 s        |
| 03 | scene03_data.py                   | Sample funnel                | 40 s        |
| 04 | scene04_model.py                  | Model in one line            | 70 s        |
| 05 | scene05_dropout.py                | Drop-out identification      | 60 s        |
| 06 | scene06_decomposition.py          | S1 → S2 → S3 (CENTERPIECE)   | 90 s        |
| 07 | scene07_welfare_lambda.py         | Welfare forest by λ          | 75 s        |
| 08 | scene08_policy_window.py          | Threshold-exemption ranking  | 65 s        |
| 09 | scene09_cmed_interaction.py       | Pharma double-regulation     | 40 s        |
| 10 | scene10_closing.py                | Three contributions          | 30 s        |
