"""Scene 01 — The question. Title appears centered, then docks to header.

Target: 0:25–1:10.
"""

from manim import (
    Scene, Text, VGroup, Square, Dot, Line, Arrow, FadeIn, FadeOut,
    Transform, ORIGIN, UP, DOWN, LEFT, RIGHT, DashedVMobject,
)
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from theme import (
    configure_manim, BG, INK, INK_SOFT, RED_SME, BLUE_NS,
    FONT_TITLE, FONT_BODY, SIZE_LARGE, SIZE_BODY,
    header_strip, title_card, pad_to_target,
)


class SceneQuestion(Scene):
    def setup(self):
        configure_manim()
        self.camera.background_color = BG

    def construct(self):
        # 1) Paper title appears centered.
        title = title_card(
            "The Cost of Inclusion",
            "Decomposing Bidder Exclusion in Public Procurement",
        )
        self.play(FadeIn(title, shift=0.2 * DOWN), run_time=0.8)
        self.wait(2.5)

        # 2) Title docks to the top-left as the persistent header.
        header = header_strip()
        self.play(Transform(title, header), run_time=0.9)
        self.remove(title)
        self.add(header)

        # 3) Center question.
        question = Text(
            "SME set-asides in public procurement —\n"
            "how much do they cost, and through which margin?",
            font=FONT_TITLE, color=INK, line_spacing=1.2,
        ).scale(SIZE_LARGE / 36).move_to(0.6 * UP)
        self.play(FadeIn(question), run_time=0.6)
        self.wait(1.2)

        # 4) Two icons (SME shop / non-SME factory) with gavel between them.
        sme_box = Square(side_length=1.0, color=RED_SME, fill_opacity=0.15,
                         stroke_color=RED_SME).shift(2.5 * LEFT + 1.4 * DOWN)
        sme_lbl = Text("SME", font=FONT_BODY, color=RED_SME)\
            .scale(0.55).next_to(sme_box, DOWN, buff=0.18)

        ns_box = Square(side_length=1.5, color=BLUE_NS, fill_opacity=0.15,
                        stroke_color=BLUE_NS).shift(2.5 * RIGHT + 1.4 * DOWN)
        ns_lbl = Text("non-SME", font=FONT_BODY, color=BLUE_NS)\
            .scale(0.55).next_to(ns_box, DOWN, buff=0.18)

        gavel = Text("§", font=FONT_TITLE, color=INK, weight="BOLD")\
            .scale(1.6).move_to(1.4 * DOWN)

        self.play(
            FadeIn(sme_box, shift=0.2 * UP),
            FadeIn(sme_lbl),
            FadeIn(ns_box, shift=0.2 * UP),
            FadeIn(ns_lbl),
            FadeIn(gavel),
            run_time=0.8,
        )
        self.wait(1.2)

        # 5) Dotted red perimeter snaps around SME — the "SME-only" rule.
        ring = DashedVMobject(
            Square(side_length=1.6, color=RED_SME, stroke_width=3)
            .move_to(sme_box.get_center()),
            num_dashes=24,
        )
        ring_lbl = Text("SME-only", font=FONT_BODY, color=RED_SME, weight="MEDIUM")\
            .scale(0.55).next_to(ring, UP, buff=0.18)
        self.play(FadeIn(ring), FadeIn(ring_lbl), run_time=0.6)

        self.wait(2.0)
        pad_to_target(self, "SceneQuestion")
        self.play(
            FadeOut(VGroup(question, sme_box, sme_lbl, ns_box, ns_lbl,
                           gavel, ring, ring_lbl)),
            run_time=0.6,
        )
        # leave header on screen for the next scene
