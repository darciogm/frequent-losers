"""Scene 02 — March 2018 reinterpretation as natural experiment.

Target: 1:10–2:10.
"""

from manim import (
    Scene, Text, VGroup, Rectangle, Line, Arrow, FadeIn, FadeOut,
    Indicate, Transform, ORIGIN, UP, DOWN, LEFT, RIGHT, np,
)
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from theme import (
    configure_manim, BG, INK, INK_SOFT, GRID, RED_SME, BLUE_NS,
    FONT_TITLE, FONT_BODY, SIZE_BODY, header_strip,
)


class SceneNaturalExperiment(Scene):
    def setup(self):
        configure_manim()
        self.camera.background_color = BG

    def construct(self):
        self.add(header_strip())

        # 1) Horizontal timeline 2014 → 2019 with March-2018 marker.
        x0, x1 = -5.5, 5.5
        timeline = Line(x0 * RIGHT, x1 * RIGHT, color=GRID, stroke_width=2)
        years = ["2014", "2016", "2018", "2019"]
        positions = np.linspace(x0, x1, len(years))
        ticks = VGroup(*[
            VGroup(
                Line(p * RIGHT + 0.1 * UP, p * RIGHT + 0.1 * DOWN,
                     color=GRID, stroke_width=1.5),
                Text(y, font=FONT_BODY, color=INK_SOFT).scale(0.4)
                .move_to(p * RIGHT + 0.45 * DOWN),
            )
            for p, y in zip(positions, years)
        ])
        cutoff_x = positions[2] - 0.4   # March 2018 sits just before the 2018 tick
        cutoff_marker = Line(cutoff_x * RIGHT + 0.5 * UP,
                             cutoff_x * RIGHT + 0.5 * DOWN,
                             color=RED_SME, stroke_width=4)
        cutoff_lbl = Text("March 2018", font=FONT_BODY, color=RED_SME,
                          weight="MEDIUM").scale(0.45)\
            .move_to(cutoff_x * RIGHT + 0.95 * UP)

        self.play(FadeIn(timeline), FadeIn(ticks), run_time=0.6)
        self.play(FadeIn(cutoff_marker), FadeIn(cutoff_lbl), run_time=0.4)
        self.play(Indicate(cutoff_marker, color=RED_SME, scale_factor=1.2),
                  run_time=0.6)

        # 2) Group-65 block above the line: blue (open) flips to red (SME-only).
        g65_pre = Rectangle(width=cutoff_x - x0, height=0.55,
                            color=BLUE_NS, fill_opacity=0.35,
                            stroke_color=BLUE_NS)\
            .move_to((x0 + cutoff_x) / 2 * RIGHT + 1.5 * UP)
        g65_post = Rectangle(width=x1 - cutoff_x, height=0.55,
                             color=RED_SME, fill_opacity=0.35,
                             stroke_color=RED_SME)\
            .move_to((cutoff_x + x1) / 2 * RIGHT + 1.5 * UP)
        g65_lbl_pre = Text("Group 65 — open tenders",
                           font=FONT_BODY, color=BLUE_NS).scale(0.4)\
            .move_to(g65_pre.get_center())
        g65_lbl_post = Text("SME-only", font=FONT_BODY, color=RED_SME,
                            weight="MEDIUM").scale(0.4)\
            .move_to(g65_post.get_center())

        self.play(FadeIn(g65_pre), FadeIn(g65_lbl_pre), run_time=0.5)
        self.wait(0.8)
        self.play(FadeIn(g65_post), FadeIn(g65_lbl_post), run_time=0.5)

        # 3) 76 always-treated control groups below the line.
        n_controls = 12  # visual abstraction; label says "76"
        controls = VGroup(*[
            Rectangle(width=(x1 - x0) / n_controls - 0.05, height=0.18,
                      color=GRID, fill_opacity=0.4, stroke_width=0)
            .move_to(((x0 + (i + 0.5) * (x1 - x0) / n_controls) * RIGHT
                      + (-1.6 - (i % 4) * 0.25) * UP))
            for i in range(n_controls)
        ])
        controls_lbl = Text("76 always-treated control groups — unchanged",
                            font=FONT_BODY, color=INK_SOFT).scale(0.45)\
            .move_to(2.65 * DOWN)

        self.play(FadeIn(controls, lag_ratio=0.05), run_time=0.8)
        self.play(FadeIn(controls_lbl), run_time=0.4)

        # 4) Annotation about exogeneity.
        annot = VGroup(
            Text("Triggered by a legalistic reinterpretation at PGE-SP.",
                 font=FONT_TITLE, color=INK, slant="ITALIC").scale(0.5),
            Text("Not a response to prices, competition, or supplier complaints.",
                 font=FONT_TITLE, color=INK_SOFT, slant="ITALIC").scale(0.45),
        ).arrange(DOWN, buff=0.2).move_to(3.0 * UP + 0.0 * RIGHT)

        # nudge to top safe area without colliding with header
        annot.move_to(2.7 * UP)
        self.play(FadeIn(annot, shift=0.1 * DOWN), run_time=0.6)

        self.wait(3.0)
        self.play(
            FadeOut(VGroup(timeline, ticks, cutoff_marker, cutoff_lbl,
                           g65_pre, g65_post, g65_lbl_pre, g65_lbl_post,
                           controls, controls_lbl, annot)),
            run_time=0.6,
        )
