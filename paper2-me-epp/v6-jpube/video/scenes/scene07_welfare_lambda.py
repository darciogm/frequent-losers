"""Scene 07 — Welfare forest plot animated by λ; right-side MCPF dial.

Numbers (welfare loss % at each λ for pharma vs non-pharma) loaded from
assets/welfare_lambda_grid.json once you confirm them against
output/tables/tab_v3_welfare.tex / tab_welfare_ranking_lambda.tex.

Target: 6:30–7:45.
"""

from manim import (
    Scene, Text, VGroup, Rectangle, Line, Dot, Axes, FadeIn, FadeOut,
    ORIGIN, UP, DOWN, LEFT, RIGHT, np, Group)
import sys, pathlib, json
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from theme import (
    configure_manim, BG, INK, INK_SOFT, GRID, RED_SME, BLUE_NS, AMBER_WARN,
    FONT_TITLE, FONT_BODY, header_strip, overlay_quote, pad_to_target,
)


def load_grid():
    p = pathlib.Path(__file__).resolve().parents[1] / "assets" \
        / "welfare_lambda_grid.json"
    if p.exists():
        return json.loads(p.read_text())
    # Placeholders (CONFIRM against tab_v3_welfare.tex before final render).
    return {
        "lambdas": [0.15, 0.20, 0.30, 0.40, 0.45],
        "pharma":  [26.3, 30.0, 33.7, 46.4, 50.3],
        "non_pharma": [12.4, 14.2, 18.0, 24.6, 27.1],
        "ci_pharma": [(22, 30), (26, 34), (29, 38), (40, 53), (43, 57)],
        "ci_nonpharma": [(9, 16), (11, 18), (14, 22), (20, 30), (22, 33)],
    }


class SceneWelfareLambda(Scene):
    def setup(self):
        configure_manim()
        self.camera.background_color = BG

    def construct(self):
        self.add(header_strip())
        g = load_grid()

        # Forest plot axes on the left two-thirds.
        ax = Axes(
            x_range=[0, 65, 10], y_range=[-0.5, len(g["lambdas"]) - 0.5, 1],
            x_length=8.0, y_length=4.5, tips=False,
            axis_config={"color": GRID, "stroke_width": 1.2,
                          "include_numbers": False, "font_size": 14},
        ).move_to(0.6 * LEFT + 0.2 * DOWN)

        x_lbl = Text("welfare loss (% of baseline price)",
                     font=FONT_BODY, color=INK_SOFT)\
            .scale(0.42).next_to(ax, DOWN, buff=0.25)
        self.play(FadeIn(ax), FadeIn(x_lbl), run_time=0.5)

        # x-axis tick numbers
        for tx in [10, 20, 30, 40, 50, 60]:
            tick = Text(str(tx), font=FONT_BODY, color=INK_SOFT).scale(0.3)\
                .move_to(ax.c2p(tx, -0.5) + 0.18 * DOWN)
            self.add(tick)

        for i, lam in enumerate(g["lambdas"]):
            y = i  # row index from bottom up
            row_lbl = Text(f"λ = {lam:.2f}", font=FONT_BODY, color=INK,
                           weight="MEDIUM").scale(0.4)\
                .move_to(ax.c2p(0, y) + 1.15 * LEFT)
            self.play(FadeIn(row_lbl), run_time=0.25)

            # Pharma row (red)
            ph_lo, ph_hi = g["ci_pharma"][i]
            ph_pt = g["pharma"][i]
            ph_ci = Line(ax.c2p(ph_lo, y + 0.18),
                         ax.c2p(ph_hi, y + 0.18),
                         color=RED_SME, stroke_width=2.5)
            ph_dot = Dot(ax.c2p(ph_pt, y + 0.18), color=RED_SME, radius=0.07)

            # Non-pharma row (blue)
            np_lo, np_hi = g["ci_nonpharma"][i]
            np_pt = g["non_pharma"][i]
            np_ci = Line(ax.c2p(np_lo, y - 0.18),
                         ax.c2p(np_hi, y - 0.18),
                         color=BLUE_NS, stroke_width=2.5)
            np_dot = Dot(ax.c2p(np_pt, y - 0.18), color=BLUE_NS, radius=0.07)

            self.play(FadeIn(ph_ci), FadeIn(ph_dot),
                      FadeIn(np_ci), FadeIn(np_dot), run_time=0.45)

        # Legend.
        legend = VGroup(
            VGroup(Dot(color=RED_SME, radius=0.06),
                   Text(" pharma (CMED-regulated)", font=FONT_BODY,
                        color=INK_SOFT).scale(0.38)).arrange(buff=0.1),
            VGroup(Dot(color=BLUE_NS, radius=0.06),
                   Text(" non-pharma", font=FONT_BODY, color=INK_SOFT)
                   .scale(0.38)).arrange(buff=0.1),
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.12)\
         .next_to(ax, UP, buff=0.25).align_to(ax, LEFT)
        self.play(FadeIn(legend), run_time=0.4)

        # MCPF dial on the right.
        dial_x = 5.4
        dial_axis = Line(dial_x * RIGHT + 1.8 * UP,
                         dial_x * RIGHT + 1.8 * DOWN,
                         color=GRID, stroke_width=1.5)
        dial_lbl = Text("MCPF λ", font=FONT_BODY, color=INK_SOFT,
                        weight="MEDIUM").scale(0.42)\
            .next_to(dial_axis, UP, buff=0.2)
        anchors = [
            ("US ~0.20", 0.20, BLUE_NS),
            ("OECD ~0.30", 0.30, INK_SOFT),
            ("Brazil ~0.40", 0.40, RED_SME),
        ]
        anchor_marks = VGroup()
        for name, val, color in anchors:
            y = 1.8 - (val - 0.10) / (0.50 - 0.10) * 3.6
            tick = Line(dial_x * RIGHT + y * UP + 0.15 * LEFT,
                        dial_x * RIGHT + y * UP + 0.15 * RIGHT,
                        color=color, stroke_width=2.5)
            txt = Text(name, font=FONT_BODY, color=color).scale(0.35)\
                .next_to(tick, RIGHT, buff=0.18)
            anchor_marks.add(tick, txt)

        self.play(FadeIn(dial_axis), FadeIn(dial_lbl),
                  FadeIn(anchor_marks), run_time=0.7)

        # Critical-moment overlay.
        punchline = overlay_quote(
            "At λ = 0.40 (Brazilian MCPF), total welfare loss reaches\n"
            "~50% of baseline price in pharma.",
            position=3.0 * DOWN,
            color=INK,
        )
        self.play(FadeIn(punchline, shift=0.1 * UP), run_time=0.7)

        self.wait(3.0)
        pad_to_target(self, "SceneWelfareLambda")
        self.play(FadeOut(Group(*self.mobjects)), run_time=0.6)
