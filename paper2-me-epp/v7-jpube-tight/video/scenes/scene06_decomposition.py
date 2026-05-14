"""Scene 06 — CENTERPIECE. S1 / S2 / S3 with non-monotonic ordering
(S1 < S3 < S2) and the 74/26 donut from tab_v3_bne_decomp.tex.

S2 is the counterfactual price under the SME-only rule with the *Pre*
entry pool — i.e., the rule's restriction effect with no entry response.
S3 is the actual Post price with the observed endogenous SME entry,
which partially offsets the restriction. So the audio's "endogenous
entry attenuated a latent shock 50–60% larger" maps cleanly to the
gap between S2 and S3.

The donut highlights "sheltered bidding" (intensive margin, ~74%) as
the dominant channel — that is the term the NotebookLM hosts coined
and we mirror it in the overlay.

Target: 9:10 -- 11:42 (152 s).
"""

from manim import (
    Scene, Text, VGroup, Group, Rectangle, Annulus, AnnularSector,
    FadeIn, FadeOut, AnimationGroup, ORIGIN, UP, DOWN, LEFT, RIGHT,
    ValueTracker, always_redraw, np, PI, Line,
)
import sys, pathlib, json
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from theme import (
    configure_manim, BG, INK, INK_SOFT, GRID, RED_SME, BLUE_NS, AMBER_WARN,
    FONT_TITLE, FONT_BODY, header_strip, overlay_quote, pad_to_target,
)


def load_numbers():
    """Read the canonical S1/S2/S3 figures and intensive/extensive
    shares from assets/decomposition_numbers.json (sourced from
    tab_v3_bne_decomp.tex)."""
    p = pathlib.Path(__file__).resolve().parents[1] / "assets" \
        / "decomposition_numbers.json"
    if p.exists():
        return json.loads(p.read_text())
    return {
        "s1_index": 100.0,
        "s2_index": 151.8,
        "s3_index": 134.1,
        "intensive_share": 0.745,
        "extensive_share": 0.255,
    }


class SceneDecomposition(Scene):
    def setup(self):
        configure_manim()
        self.camera.background_color = BG

    def construct(self):
        header = header_strip()
        self.add(header)
        d = load_numbers()
        s1, s2, s3 = d["s1_index"], d["s2_index"], d["s3_index"]
        intensive = d["intensive_share"]
        extensive = d["extensive_share"]

        # Bars left-aligned, ordered S1 (top), S2 (middle), S3 (bottom).
        # Width unit is set off the LARGEST value (S2) so all three fit.
        bar_x_left = -5.0
        bar_y_top = 1.6
        bar_height = 0.55
        bar_gap = 0.32
        max_w = 5.0
        unit = max_w / max(s1, s2, s3)

        def make_bar(value, y, color, label, sublabel,
                      fill_opacity=0.55, stroke_dashed=False):
            r = Rectangle(width=value * unit, height=bar_height,
                          color=color, fill_opacity=fill_opacity,
                          stroke_color=color, stroke_width=1.5)\
                .move_to((bar_x_left + value * unit / 2) * RIGHT + y * UP)
            n = Text(f"{value:.0f}", font=FONT_TITLE, color=color,
                     weight="MEDIUM").scale(0.42)\
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
                         "S2", "Restricted, no entry adjustment")
        bar3 = make_bar(s3, bar_y_top - 2 * (bar_height + bar_gap),
                         AMBER_WARN,
                         "S3", "Restricted + endogenous SME entry")

        self.play(FadeIn(bar1), run_time=0.7)
        self.wait(1.5)
        # The intensive shock: S1 -> S2.
        self.play(FadeIn(bar2, shift=0.2 * RIGHT), run_time=0.9)
        intensive_arrow = Line(
            (bar_x_left + s1 * unit) * RIGHT + bar_y_top * UP,
            (bar_x_left + s2 * unit) * RIGHT
                + (bar_y_top - (bar_height + bar_gap)) * UP,
            color=RED_SME, stroke_width=2,
        )
        intensive_lbl = Text("intensive (sheltered bidding)",
                              font=FONT_BODY, color=RED_SME,
                              weight="MEDIUM").scale(0.36)\
            .next_to(intensive_arrow.get_center(), RIGHT, buff=0.15)
        self.play(FadeIn(intensive_arrow), FadeIn(intensive_lbl),
                  run_time=0.6)
        self.wait(2.0)

        # The extensive offset: S2 -> S3 (entry brings price down).
        self.play(FadeIn(bar3, shift=0.2 * RIGHT), run_time=0.9)
        extensive_arrow = Line(
            (bar_x_left + s2 * unit) * RIGHT
                + (bar_y_top - (bar_height + bar_gap)) * UP,
            (bar_x_left + s3 * unit) * RIGHT
                + (bar_y_top - 2 * (bar_height + bar_gap)) * UP,
            color=AMBER_WARN, stroke_width=2,
        )
        extensive_lbl = Text("extensive (endogenous entry, partial offset)",
                              font=FONT_BODY, color=AMBER_WARN,
                              weight="MEDIUM").scale(0.36)\
            .next_to(extensive_arrow.get_center(), RIGHT, buff=0.15)
        self.play(FadeIn(extensive_arrow), FadeIn(extensive_lbl),
                  run_time=0.6)
        self.wait(2.0)

        # Donut chart (right).
        donut_center = 4.6 * RIGHT + 0.5 * UP
        donut_back = Annulus(inner_radius=0.55, outer_radius=0.9,
                              color=GRID, fill_opacity=0.3)\
            .move_to(donut_center)
        donut_int = AnnularSector(
            inner_radius=0.55, outer_radius=0.9,
            start_angle=PI / 2, angle=-2 * PI * intensive,
            color=RED_SME, fill_opacity=0.85,
        ).move_to(donut_center)
        donut_ext = AnnularSector(
            inner_radius=0.55, outer_radius=0.9,
            start_angle=PI / 2 - 2 * PI * intensive,
            angle=-2 * PI * extensive,
            color=AMBER_WARN, fill_opacity=0.85,
        ).move_to(donut_center)
        donut_pct = Text(f"{intensive * 100:.0f}%", font=FONT_TITLE,
                          color=RED_SME, weight="BOLD")\
            .scale(0.95).move_to(donut_center)
        donut_caption = VGroup(
            Text("intensive margin", font=FONT_BODY, color=RED_SME,
                 weight="MEDIUM").scale(0.42),
            Text("(bid behavior)", font=FONT_BODY, color=INK_SOFT)
            .scale(0.34),
        ).arrange(DOWN, buff=0.1).next_to(donut_back, DOWN, buff=0.45)

        self.play(FadeIn(donut_back), run_time=0.4)
        self.play(FadeIn(donut_int), FadeIn(donut_ext),
                  FadeIn(donut_pct), FadeIn(donut_caption), run_time=0.9)
        self.wait(3.0)

        # Punchline overlay.
        punchline = overlay_quote(
            "It's not who enters — it's how the survivors bid.",
            position=2.8 * DOWN,
            color=INK,
        )
        self.play(FadeIn(punchline, shift=0.1 * UP), run_time=0.8)

        # Hold to fill the 152-second audio block (the centerpiece is the
        # longest stretch where the hosts dwell on this single result).
        pad_to_target(self, "SceneDecomposition")
        to_clear = Group(*[m for m in self.mobjects if m is not header])
        self.play(FadeOut(to_clear), run_time=0.6)
