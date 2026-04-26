"""Scene 08 — Four policy options ranked by fiscal cost vs SME coverage.

Numbers loaded from assets/policy_window.json once you confirm against
output/tables/tab_v3_apv.tex and tab_v3_preference_grid.tex.

Target: 7:45–8:50.
"""

from manim import (
    Scene, Text, VGroup, Rectangle, FadeIn, FadeOut,
    ORIGIN, UP, DOWN, LEFT, RIGHT,
)
import sys, pathlib, json
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from theme import (
    configure_manim, BG, INK, INK_SOFT, GRID, RED_SME, BLUE_NS, GREEN_OK,
    FONT_TITLE, FONT_BODY, header_strip, overlay_quote,
)


def load_policies():
    p = pathlib.Path(__file__).resolve().parents[1] / "assets" \
        / "policy_window.json"
    if p.exists():
        return json.loads(p.read_text())
    # Placeholders.
    return {
        "rows": [
            {"name": "V0: SME-only across the board",
             "fiscal_cost": 100, "sme_coverage": 100, "highlight": False},
            {"name": "V1: 50/50 split",
             "fiscal_cost": 55, "sme_coverage": 50, "highlight": False},
            {"name": "V3: 10% price preference",
             "fiscal_cost": 30, "sme_coverage": 75, "highlight": False},
            {"name": "Value-threshold exemption",
             "fiscal_cost": 10, "sme_coverage": 75, "highlight": True},
        ]
    }


class ScenePolicyWindow(Scene):
    def setup(self):
        configure_manim()
        self.camera.background_color = BG

    def construct(self):
        self.add(header_strip())
        data = load_policies()

        title = Text("Four policy variants — fiscal cost vs. SME coverage",
                     font=FONT_TITLE, color=INK, weight="MEDIUM").scale(0.55)\
            .move_to(2.7 * UP)
        self.play(FadeIn(title), run_time=0.5)

        # Two columns: fiscal cost (left), SME coverage (right).
        col_x_cost = 1.2
        col_x_cov = 4.2
        max_w = 2.0
        row_height = 0.45
        row_gap = 0.35
        y0 = 1.6

        for i, row in enumerate(data["rows"]):
            y = y0 - i * (row_height + row_gap)
            color = GREEN_OK if row["highlight"] else INK
            row_lbl = Text(row["name"], font=FONT_TITLE, color=color,
                           weight="MEDIUM" if row["highlight"] else "NORMAL")\
                .scale(0.42).move_to(LEFT * 4.5 + UP * y).align_to(LEFT * 6.5, LEFT)

            cost_w = row["fiscal_cost"] / 100 * max_w
            cost_bar = Rectangle(width=cost_w, height=row_height,
                                  color=RED_SME if row["highlight"]
                                  else INK_SOFT,
                                  fill_opacity=0.55, stroke_width=0)\
                .move_to((col_x_cost + cost_w / 2) * RIGHT + y * UP)
            cost_lbl = Text(f"{row['fiscal_cost']}%", font=FONT_BODY,
                            color=INK).scale(0.4)\
                .next_to(cost_bar, RIGHT, buff=0.12)

            cov_w = row["sme_coverage"] / 100 * max_w
            cov_bar = Rectangle(width=cov_w, height=row_height,
                                 color=GREEN_OK if row["highlight"]
                                 else BLUE_NS,
                                 fill_opacity=0.55, stroke_width=0)\
                .move_to((col_x_cov + cov_w / 2) * RIGHT + y * UP)
            cov_lbl = Text(f"{row['sme_coverage']}%", font=FONT_BODY,
                           color=INK).scale(0.4)\
                .next_to(cov_bar, RIGHT, buff=0.12)

            self.play(FadeIn(row_lbl, shift=0.1 * RIGHT),
                      FadeIn(cost_bar, shift=0.1 * RIGHT),
                      FadeIn(cost_lbl),
                      FadeIn(cov_bar, shift=0.1 * RIGHT),
                      FadeIn(cov_lbl),
                      run_time=0.45)
            self.wait(0.2)

        # Column headers.
        h_cost = Text("Fiscal cost", font=FONT_BODY, color=INK_SOFT,
                      weight="MEDIUM").scale(0.4)\
            .move_to(col_x_cost * RIGHT + (y0 + 0.55) * UP)
        h_cov = Text("SME coverage", font=FONT_BODY, color=INK_SOFT,
                     weight="MEDIUM").scale(0.4)\
            .move_to(col_x_cov * RIGHT + (y0 + 0.55) * UP)
        self.play(FadeIn(h_cost), FadeIn(h_cov), run_time=0.4)

        overlay = overlay_quote(
            "92% of procurement value sits in the top 25% of items.\n"
            "Apply SME-only to the bottom 75% only:\n"
            "recover 90% of the fiscal cost while preserving 75% of the preference.",
            position=2.4 * DOWN,
            color=INK,
        )
        self.play(FadeIn(overlay, shift=0.1 * UP), run_time=0.8)

        self.wait(2.5)
        self.play(FadeOut(VGroup(*self.mobjects)), run_time=0.6)
