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
    FONT_TITLE, FONT_BODY, header_strip, title_card,
)


class SceneClosing(Scene):
    def setup(self):
        configure_manim()
        self.camera.background_color = BG

    def construct(self):
        self.add(header_strip())

        contribs = [
            "1. Structural decomposition of the SME effect into intensive and extensive margins.",
            "2. Cross-format Pregão–Convite identification as a primitive-invariance test.",
            "3. Conditional welfare ranking — operational, not absolute.",
        ]
        items = VGroup(*[
            Text(line, font=FONT_TITLE, color=INK, line_spacing=1.15)
            .scale(0.55) for line in contribs
        ]).arrange(DOWN, aligned_edge=LEFT, buff=0.55).move_to(0.7 * UP)

        for it in items:
            self.play(FadeIn(it, shift=0.1 * RIGHT), run_time=0.6)
            self.wait(0.3)

        # Footer.
        cite = Text(
            "Genicolo-Martins, D. (2026). \"The Cost of Inclusion.\" "
            "Working paper, Insper.",
            font=FONT_BODY, color=INK_SOFT, slant="ITALIC",
        ).scale(0.45).move_to(2.3 * DOWN)
        url = Text("darciogm.github.io/research/sme-public/",
                   font=FONT_BODY, color=RED_SME, weight="MEDIUM")\
            .scale(0.45).next_to(cite, DOWN, buff=0.2)
        self.play(FadeIn(cite), FadeIn(url), run_time=0.6)

        self.wait(2.5)

        # Title fades back in for sign-off.
        title_back = title_card("The Cost of Inclusion")
        self.play(FadeOut(items), FadeOut(cite), FadeOut(url), run_time=0.6)
        self.play(FadeIn(title_back, shift=0.1 * DOWN), run_time=0.7)
        self.wait(2.0)
        self.play(FadeOut(title_back), run_time=0.6)
