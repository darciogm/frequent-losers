"""Scene 03 — Sample funnel with three Pre/Post badges.

Target: 2:10–2:50.
"""

from manim import (
    Scene, Text, VGroup, Rectangle, Arrow, FadeIn, FadeOut,
    ORIGIN, UP, DOWN, LEFT, RIGHT,
)
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from theme import (
    configure_manim, BG, INK, INK_SOFT, GRID, GREEN_OK, RED_SME,
    FONT_TITLE, FONT_BODY, header_strip, pad_to_target,
)


def funnel_box(label_top: str, label_bot: str, color=INK):
    box = Rectangle(width=4.4, height=0.85, color=GRID,
                    stroke_width=1.5, fill_opacity=0.05)
    n  = Text(label_top, font=FONT_TITLE, color=color, weight="MEDIUM")\
        .scale(0.55).move_to(box.get_center() + 0.18 * UP)
    sub = Text(label_bot, font=FONT_BODY, color=INK_SOFT)\
        .scale(0.4).move_to(box.get_center() + 0.22 * DOWN)
    return VGroup(box, n, sub)


class SceneData(Scene):
    def setup(self):
        configure_manim()
        self.camera.background_color = BG

    def construct(self):
        self.add(header_strip())

        rows = [
            ("3,700,000", "raw observations (BEC microdata)"),
            ("Group 65 only", "medical, dental, hospital supplies"),
            ("Pregão only", "electronic descending-clock auction"),
            ("297,967 / 97,993", "firm-auction obs / distinct auctions"),
        ]
        boxes = VGroup(*[funnel_box(t, b) for (t, b) in rows])\
            .arrange(DOWN, buff=0.55).shift(0.5 * LEFT)

        # Color the final box red to mark the structural sample.
        final_box = boxes[-1][0]
        final_box.set_stroke(RED_SME, width=2)
        boxes[-1][1].set_color(RED_SME)

        # Arrows between boxes.
        arrows = VGroup(*[
            Arrow(boxes[i].get_bottom() + 0.05 * DOWN,
                  boxes[i + 1].get_top() + 0.05 * UP,
                  color=GRID, buff=0.05, stroke_width=2,
                  max_tip_length_to_length_ratio=0.18)
            for i in range(len(rows) - 1)
        ])

        self.play(FadeIn(boxes[0], shift=0.2 * DOWN), run_time=0.5)
        for i in range(1, len(rows)):
            self.play(
                FadeIn(arrows[i - 1]),
                FadeIn(boxes[i], shift=0.2 * DOWN),
                run_time=0.45,
            )
            self.wait(0.3)

        # Right-side validation badges.
        badges = VGroup(
            Text("Pre/Post balanced", font=FONT_BODY, color=GREEN_OK).scale(0.45),
            Text("No discontinuity at the cutoff",
                 font=FONT_BODY, color=GREEN_OK).scale(0.45),
            Text("Cross-validated against RAIS",
                 font=FONT_BODY, color=GREEN_OK).scale(0.45),
        ).arrange(DOWN, buff=0.45).move_to(4.2 * RIGHT)

        for b in badges:
            self.play(FadeIn(b, shift=0.15 * LEFT), run_time=0.4)

        self.wait(2.5)
        pad_to_target(self, "SceneData")
        self.play(FadeOut(VGroup(boxes, arrows, badges)), run_time=0.6)
