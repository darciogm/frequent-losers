"""Scene 10 — Three contributions + citation footer.

Target: 9:30–10:00.
"""

from manim import (
    Scene, Text, VGroup, FadeIn, FadeOut,
    ORIGIN, UP, DOWN, LEFT, RIGHT,
)
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from theme import (
    configure_manim, BG, INK, INK_SOFT, RED_SME,
    FONT_TITLE, FONT_BODY, header_strip, title_card, pad_to_target,
)


class SceneClosing(Scene):
    def setup(self):
        configure_manim()
        self.camera.background_color = BG

    def construct(self):
        self.add(header_strip())

        contribs = [
            "1. The SME-only rule raises prices roughly 11%.",
            "2. ~74% of the effect runs through bid behavior, not entry.",
            "3. A 10% price preference recovers most of the loss at near-zero fiscal cost.",
        ]
        items = VGroup(*[
            Text(line, font=FONT_TITLE, color=INK, line_spacing=1.15)
            .scale(0.55) for line in contribs
        ]).arrange(DOWN, aligned_edge=LEFT, buff=0.55).move_to(1.0 * UP)

        for it in items:
            self.play(FadeIn(it, shift=0.1 * RIGHT), run_time=0.6)
            self.wait(0.3)

        # Sandbox-paradox closing — the twist the NotebookLM hosts left
        # on the table at ~16:30. Bait the listener with the open question.
        paradox = VGroup(
            Text("And one open question.", font=FONT_TITLE, color=INK_SOFT,
                 slant="ITALIC", weight="MEDIUM").scale(0.5),
            Text("If sheltered SMEs never have to race the giants,",
                 font=FONT_TITLE, color=INK).scale(0.45),
            Text("do they ever grow into the giants the policy meant to challenge?",
                 font=FONT_TITLE, color=RED_SME, slant="ITALIC",
                 weight="MEDIUM").scale(0.45),
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.22).next_to(items, DOWN, buff=0.7)
        for line in paradox:
            self.play(FadeIn(line, shift=0.05 * RIGHT), run_time=0.5)
            self.wait(0.4)

        # Footer.
        cite = Text(
            "Genicolo-Martins, D. (2026). \"The Cost of Inclusion.\" "
            "Working paper, Insper.",
            font=FONT_BODY, color=INK_SOFT, slant="ITALIC",
        ).scale(0.42).move_to(3.0 * DOWN)
        url = Text("darciogm.github.io/research/sme-public/",
                   font=FONT_BODY, color=RED_SME, weight="MEDIUM")\
            .scale(0.42).next_to(cite, DOWN, buff=0.18)
        self.play(FadeIn(cite), FadeIn(url), run_time=0.6)
        self.wait(2.0)

        # Title fades back in for sign-off.
        title_back = title_card("The Cost of Inclusion")
        self.play(FadeOut(items), FadeOut(paradox),
                  FadeOut(cite), FadeOut(url), run_time=0.6)
        self.play(FadeIn(title_back, shift=0.1 * DOWN), run_time=0.7)
        pad_to_target(self, "SceneClosing")
        self.play(FadeOut(title_back), run_time=0.6)
