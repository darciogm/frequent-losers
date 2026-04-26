"""Scene 04 — Model in one line: cost distribution + equilibrium bid + ECDF.

Target: 2:50–4:00.
"""

from manim import (
    Scene, Text, MathTex, VGroup, Axes, Dot, FadeIn, FadeOut,
    ORIGIN, UP, DOWN, LEFT, RIGHT, np,
)
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from theme import (
    configure_manim, BG, INK, INK_SOFT, GRID, RED_SME, BLUE_NS,
    FONT_TITLE, FONT_BODY, header_strip,
)


class SceneModel(Scene):
    def setup(self):
        configure_manim()
        self.camera.background_color = BG

    def construct(self):
        self.add(header_strip())

        # 1) Cost-distribution equation (top half).
        eq1 = MathTex(
            r"c_i \sim F_c^{\,k}(\cdot \mid X), \quad",
            r"k \in \{\text{SME},\,\text{non-SME}\}",
        ).scale(0.95).move_to(2.0 * UP)
        eq1[0].set_color(INK)
        eq1[1].set_color(INK_SOFT)
        self.play(FadeIn(eq1, shift=0.1 * DOWN), run_time=0.7)
        self.wait(1.3)

        # 2) Equilibrium bid function.
        eq2 = MathTex(
            r"b_i^{\ast}(c_i;\,n)\;=\;c_i\;+\;",
            r"\frac{1}{n-1}\,\frac{1-F_c(c_i)}{f_c(c_i)}",
        ).scale(0.95).move_to(0.7 * UP)
        eq2[0].set_color(INK)
        eq2[1].set_color(RED_SME)
        self.play(FadeIn(eq2, shift=0.1 * DOWN), run_time=0.7)
        self.wait(1.5)

        # 3) ECDF on [0, 3] in ref-units, with c_(2) marker on the right.
        ax = Axes(
            x_range=[0, 3, 1], y_range=[0, 1.05, 0.5],
            x_length=4.8, y_length=2.0,
            tips=False,
            axis_config={"color": GRID, "stroke_width": 1.2,
                          "include_numbers": True,
                          "font_size": 18},
        ).move_to(1.7 * DOWN + 2.4 * LEFT)
        x_lbl = Text("c (ref-units)", font=FONT_BODY, color=INK_SOFT)\
            .scale(0.35).next_to(ax, DOWN, buff=0.18)
        y_lbl = Text("F_c(c)", font=FONT_BODY, color=INK_SOFT)\
            .scale(0.35).next_to(ax, LEFT, buff=0.15)

        # Beta-like CDF for visual; not a calibrated estimate.
        def cdf(c):
            x = np.clip(c / 3.0, 0, 1)
            return float(1 - (1 - x) ** 2.4)

        curve = ax.plot(cdf, x_range=[0.01, 2.99], color=INK, stroke_width=2.5)

        # Mark c_(2) at ~ 1.4
        c2_x = 1.4
        c2_dot = Dot(ax.c2p(c2_x, cdf(c2_x)), color=RED_SME, radius=0.06)
        c2_lbl = MathTex(r"c_{(2)}", color=RED_SME).scale(0.6)\
            .next_to(c2_dot, UP + RIGHT, buff=0.1)

        self.play(FadeIn(ax), FadeIn(x_lbl), FadeIn(y_lbl), run_time=0.5)
        self.play(FadeIn(curve), run_time=0.8)
        self.play(FadeIn(c2_dot), FadeIn(c2_lbl), run_time=0.4)

        # 4) Right-side annotations.
        annot_top = Text(
            "Winning ≠ paying your own cost.\n"
            "Winning = paying the runner-up's cost.",
            font=FONT_TITLE, color=INK, slant="ITALIC", line_spacing=1.2,
        ).scale(0.5).move_to(1.2 * DOWN + 3.2 * RIGHT)
        annot_bot = Text(
            "More firms → tougher runner-up → lower price.\n"
            "Remove firms → higher price.",
            font=FONT_BODY, color=INK_SOFT, line_spacing=1.2,
        ).scale(0.42).next_to(annot_top, DOWN, buff=0.35)
        annot_q = Text(
            "But how much from who shows up,\nvs. how each one bids?",
            font=FONT_TITLE, color=RED_SME, weight="MEDIUM", line_spacing=1.2,
        ).scale(0.45).next_to(annot_bot, DOWN, buff=0.3)

        self.play(FadeIn(annot_top, shift=0.1 * LEFT), run_time=0.6)
        self.wait(0.8)
        self.play(FadeIn(annot_bot, shift=0.1 * LEFT), run_time=0.5)
        self.wait(0.6)
        self.play(FadeIn(annot_q, shift=0.1 * LEFT), run_time=0.5)

        self.wait(2.5)
        self.play(
            FadeOut(VGroup(eq1, eq2, ax, x_lbl, y_lbl, curve, c2_dot, c2_lbl,
                           annot_top, annot_bot, annot_q)),
            run_time=0.6,
        )
