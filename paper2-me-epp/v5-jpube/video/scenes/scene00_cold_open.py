"""Scene 00 — Cold open. Counter rolls 0 → R$ 85M; subline reveals.

Target: 0:00–0:25.
"""

from manim import Scene, Text, ValueTracker, always_redraw, FadeIn, FadeOut, \
    DecimalNumber, VGroup, ORIGIN, DOWN
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from theme import (
    configure_manim, BG, INK, INK_SOFT, RED_SME,
    FONT_TITLE, FONT_BODY, SIZE_HERO, SIZE_BODY,
)


class SceneColdOpen(Scene):
    def setup(self):
        configure_manim()
        self.camera.background_color = BG

    def construct(self):
        # Headline figure (R$ 85M target). Roll for 1.8s, hold for ~6s.
        tracker = ValueTracker(0.0)
        prefix = Text("R$ ", font=FONT_TITLE, color=RED_SME, weight="BOLD")\
            .scale(SIZE_HERO / 36)

        number = always_redraw(lambda: DecimalNumber(
            tracker.get_value(), num_decimal_places=0,
            include_sign=False, color=RED_SME, font_size=SIZE_HERO * 2,
        ).next_to(prefix, buff=0.15))

        suffix = Text(" million", font=FONT_TITLE, color=RED_SME, weight="BOLD")\
            .scale(SIZE_HERO / 36)

        headline = VGroup(prefix, number, suffix).arrange(buff=0.15).move_to(ORIGIN)

        sub_lines = [
            "In 18 months.",
            "In São Paulo state hospitals.",
            "On gauze, syringes, and pills.",
        ]
        subs = VGroup(*[
            Text(line, font=FONT_BODY, color=INK_SOFT).scale(SIZE_BODY / 36)
            for line in sub_lines
        ]).arrange(DOWN, buff=0.18).next_to(headline, DOWN, buff=0.9)

        # 1) hero number rolls in
        self.add(prefix, number, suffix)
        suffix.set_opacity(0)
        self.play(tracker.animate.set_value(85), run_time=1.8)
        self.play(FadeIn(suffix), run_time=0.4)

        # 2) subtitle stack reveals line by line
        for line in subs:
            self.play(FadeIn(line, shift=0.15 * DOWN), run_time=0.45)
            self.wait(0.4)

        self.wait(2.0)

        self.play(
            FadeOut(VGroup(prefix, number, suffix, subs)),
            run_time=0.6,
        )
