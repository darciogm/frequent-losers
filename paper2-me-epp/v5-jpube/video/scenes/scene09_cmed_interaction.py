"""Scene 09 — Pharma vs non-pharma loss bars + dual-regulation panel.

Target: 8:50–9:30.
"""

from manim import (
    Scene, Text, VGroup, Rectangle, Line, FadeIn, FadeOut,
    ORIGIN, UP, DOWN, LEFT, RIGHT,
)
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from theme import (
    configure_manim, BG, INK, INK_SOFT, GRID, RED_SME, BLUE_NS, AMBER_WARN,
    FONT_TITLE, FONT_BODY, header_strip, overlay_quote,
)


class SceneCMED(Scene):
    def setup(self):
        configure_manim()
        self.camera.background_color = BG

    def construct(self):
        self.add(header_strip())

        # Two side-by-side panels.
        # Left: non-pharma loss bar.
        non_pharma_w = 2.5
        non_pharma = Rectangle(width=non_pharma_w, height=1.2,
                                color=BLUE_NS, fill_opacity=0.55,
                                stroke_color=BLUE_NS)\
            .move_to(LEFT * 3.5 + UP * 0.5)
        non_pharma_lbl = Text("Non-pharma", font=FONT_TITLE, color=INK,
                              weight="MEDIUM").scale(0.5)\
            .next_to(non_pharma, UP, buff=0.25)
        non_pharma_pct = Text("welfare loss = X%",
                              font=FONT_BODY, color=INK_SOFT).scale(0.4)\
            .next_to(non_pharma, DOWN, buff=0.25)

        # Right: pharma loss bar (62% larger), red.
        pharma_w = 2.5 * 1.62
        pharma = Rectangle(width=pharma_w, height=1.2,
                            color=RED_SME, fill_opacity=0.55,
                            stroke_color=RED_SME)\
            .move_to(RIGHT * 3.0 + UP * 0.5)
        pharma_lbl = Text("Pharma (CMED-regulated)",
                          font=FONT_TITLE, color=RED_SME,
                          weight="MEDIUM").scale(0.5)\
            .next_to(pharma, UP, buff=0.25)
        pharma_pct = Text("welfare loss = X × 1.62",
                          font=FONT_BODY, color=RED_SME).scale(0.4)\
            .next_to(pharma, DOWN, buff=0.25)

        self.play(FadeIn(non_pharma_lbl), FadeIn(non_pharma),
                  FadeIn(non_pharma_pct), run_time=0.6)
        self.wait(0.5)
        self.play(FadeIn(pharma_lbl), FadeIn(pharma),
                  FadeIn(pharma_pct), run_time=0.6)

        # Dual-constraint mini-diagram below.
        box = Rectangle(width=4.0, height=2.0, color=GRID, stroke_width=1)\
            .move_to(2.0 * DOWN)
        ceiling = Line(box.get_corner(UP + LEFT) + 0.05 * DOWN,
                       box.get_corner(UP + RIGHT) + 0.05 * DOWN,
                       color=AMBER_WARN, stroke_width=3)
        ceiling_lbl = Text("CMED price ceiling", font=FONT_BODY,
                           color=AMBER_WARN, weight="MEDIUM").scale(0.35)\
            .next_to(ceiling, UP, buff=0.1).align_to(ceiling, LEFT)
        sme_wall = Line(box.get_corner(UP + RIGHT) + 0.05 * LEFT,
                        box.get_corner(DOWN + RIGHT) + 0.05 * LEFT,
                        color=RED_SME, stroke_width=3)
        sme_wall_lbl = Text("SME-only wall", font=FONT_BODY,
                            color=RED_SME, weight="MEDIUM").scale(0.35)\
            .next_to(sme_wall, RIGHT, buff=0.12)

        bid_dot = VGroup(
            Text("bid", font=FONT_BODY, color=INK,
                 weight="MEDIUM").scale(0.4),
        ).move_to(box.get_center() + 0.3 * UP + 0.5 * RIGHT)

        self.play(FadeIn(box), run_time=0.4)
        self.play(FadeIn(ceiling), FadeIn(ceiling_lbl),
                  FadeIn(sme_wall), FadeIn(sme_wall_lbl),
                  FadeIn(bid_dot), run_time=0.6)
        # bid drifts up to the ceiling
        self.play(bid_dot.animate.move_to(box.get_corner(UP + RIGHT)
                                          + 0.25 * DOWN + 0.4 * LEFT),
                  run_time=0.8)

        overlay = overlay_quote(
            "When two regulators squeeze the same bidder, the bid hits the ceiling.",
            position=3.3 * DOWN,
            color=INK,
        )
        self.play(FadeIn(overlay, shift=0.1 * UP), run_time=0.6)

        self.wait(2.0)
        self.play(FadeOut(VGroup(*self.mobjects)), run_time=0.6)
