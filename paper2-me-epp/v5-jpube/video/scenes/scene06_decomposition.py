"""Scene 06 — CENTERPIECE. S1 → S2 → S3 decomposition with two donut charts.

Numbers (XX, YY) are placeholders calibrated against tab_v3_bne_decomp.tex
in `assets/decomposition_numbers.json` once you confirm them. Keep the donut
proportions consistent with whatever percentage the table reports.

Target: 5:00–6:30.
"""

from manim import (
    Scene, Text, VGroup, Rectangle, Annulus, FadeIn, FadeOut,
    AnimationGroup, ORIGIN, UP, DOWN, LEFT, RIGHT, ValueTracker,
    always_redraw, np, Sector, PI,
)
import sys, pathlib, json
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from theme import (
    configure_manim, BG, INK, INK_SOFT, GRID, RED_SME, BLUE_NS,
    FONT_TITLE, FONT_BODY, header_strip, overlay_quote,
)


def load_numbers():
    """Pull the actual S1/S2/S3 figures from assets/ if present.

    Falls back to placeholder values that *must* be replaced before render.
    """
    p = pathlib.Path(__file__).resolve().parents[1] / "assets" \
        / "decomposition_numbers.json"
    if p.exists():
        return json.loads(p.read_text())
    return {
        "s1_index": 100.0,
        "s2_index": 108.0,    # placeholder
        "s3_index": 112.0,    # placeholder
        "intensive_share": 0.94,
        "extensive_share": 0.06,
    }


class SceneDecomposition(Scene):
    def setup(self):
        configure_manim()
        self.camera.background_color = BG

    def construct(self):
        self.add(header_strip())
        d = load_numbers()
        s1, s2, s3 = d["s1_index"], d["s2_index"], d["s3_index"]
        intensive = d["intensive_share"]
        extensive = d["extensive_share"]

        bar_x_left = -5.5
        bar_y_top = 1.6
        bar_height = 0.55
        bar_gap = 0.25
        max_w = 5.5            # frame budget for s3 bar
        unit = max_w / s3      # px per index point

        def make_bar(value, y, color, label, sublabel):
            r = Rectangle(width=value * unit, height=bar_height,
                          color=color, fill_opacity=0.55,
                          stroke_color=color, stroke_width=1.5)\
                .move_to((bar_x_left + value * unit / 2) * RIGHT + y * UP)
            n = Text(f"{value:.0f}", font=FONT_TITLE, color=color,
                     weight="MEDIUM").scale(0.45)\
                .next_to(r, RIGHT, buff=0.15)
            ll = Text(label, font=FONT_TITLE, color=INK,
                      weight="MEDIUM").scale(0.4)\
                .next_to(r, LEFT, buff=0.18)
            ll.align_to(r, UP)
            ss = Text(sublabel, font=FONT_BODY, color=INK_SOFT)\
                .scale(0.3).next_to(r, LEFT, buff=0.18)
            ss.align_to(r, DOWN)
            return VGroup(r, n, ll, ss)

        bar1 = make_bar(s1, bar_y_top, INK,
                         "S1", "Baseline: open competition")
        bar2 = make_bar(s2, bar_y_top - (bar_height + bar_gap), RED_SME,
                         "S2", "Same firms, only SMEs allowed to win")
        bar3 = make_bar(s3, bar_y_top - 2 * (bar_height + bar_gap), RED_SME,
                         "S3", "Restricted + post-policy entry pool")

        self.play(FadeIn(bar1), run_time=0.6)
        self.wait(0.4)
        self.play(FadeIn(bar2, shift=0.2 * RIGHT), run_time=0.7)
        self.wait(0.4)
        self.play(FadeIn(bar3, shift=0.2 * RIGHT), run_time=0.7)
        self.wait(0.6)

        # Two donut charts on the right.
        donut_center = 4.5 * RIGHT + 0.4 * UP
        donut_int = Sector(outer_radius=0.9, inner_radius=0.55,
                           start_angle=PI / 2,
                           angle=-2 * PI * intensive,
                           color=RED_SME, fill_opacity=0.85)\
            .move_to(donut_center)
        donut_int_back = Annulus(inner_radius=0.55, outer_radius=0.9,
                                 color=GRID, fill_opacity=0.3)\
            .move_to(donut_center)
        donut_ext = Sector(outer_radius=0.9, inner_radius=0.55,
                           start_angle=PI / 2 - 2 * PI * intensive,
                           angle=-2 * PI * extensive,
                           color=BLUE_NS, fill_opacity=0.85)\
            .move_to(donut_center)
        donut_lbl = VGroup(
            Text("Intensive margin", font=FONT_BODY, color=RED_SME,
                 weight="MEDIUM").scale(0.4),
            Text(f"{intensive*100:.0f}%", font=FONT_TITLE, color=RED_SME,
                 weight="BOLD").scale(0.7),
            Text("Extensive (entry)", font=FONT_BODY, color=BLUE_NS,
                 weight="MEDIUM").scale(0.4),
            Text(f"{extensive*100:.0f}%", font=FONT_TITLE, color=BLUE_NS,
                 weight="BOLD").scale(0.5),
        ).arrange(DOWN, buff=0.18).next_to(donut_int, DOWN, buff=0.5)

        self.play(FadeIn(donut_int_back), run_time=0.3)
        self.play(FadeIn(donut_int), FadeIn(donut_ext),
                  FadeIn(donut_lbl), run_time=0.8)

        # Punchline overlay (bottom).
        punchline = overlay_quote(
            "Almost the entire effect comes from how the surviving firms\n"
            "bid — not from who enters.",
            position=2.7 * DOWN,
            color=INK,
        )
        self.play(FadeIn(punchline, shift=0.1 * UP), run_time=0.8)

        self.wait(3.0)
        self.play(FadeOut(VGroup(*[m for m in self.mobjects
                                    if not isinstance(m, type(header_strip()))])),
                  run_time=0.6)
