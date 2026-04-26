"""Scene 05 — Drop-out identification + Pregão–Convite cross-validation.

Target: 4:00–5:00.
"""

from manim import (
    Scene, Text, VGroup, Dot, Line, Axes, FadeIn, FadeOut, ValueTracker,
    always_redraw, ORIGIN, UP, DOWN, LEFT, RIGHT, np,
)
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from theme import (
    configure_manim, BG, INK, INK_SOFT, GRID, RED_SME, BLUE_NS, GREEN_OK,
    FONT_TITLE, FONT_BODY, header_strip,
)


class SceneDropout(Scene):
    def setup(self):
        configure_manim()
        self.camera.background_color = BG

    def construct(self):
        self.add(header_strip())

        # Left half: simulated descending-clock auction.
        clock_axis = Line(LEFT * 5.5 + UP * 1.5, LEFT * 0.8 + UP * 1.5,
                          color=GRID, stroke_width=2)
        clock_lbl = Text("clock price ↓", font=FONT_BODY, color=INK_SOFT)\
            .scale(0.4).next_to(clock_axis, UP, buff=0.15)
        self.play(FadeIn(clock_axis), FadeIn(clock_lbl), run_time=0.5)

        # Four firms as colored dots.
        firm_y = [0.7, 0.1, -0.5, -1.1]
        firms = VGroup(*[
            Dot(LEFT * 5.4 + UP * y, color=BLUE_NS, radius=0.12)
            for y in firm_y
        ])
        firm_lbls = VGroup(*[
            Text(f"firm {i+1}", font=FONT_BODY, color=INK_SOFT).scale(0.35)
            .next_to(firms[i], LEFT, buff=0.12)
            for i in range(4)
        ])
        self.play(FadeIn(firms), FadeIn(firm_lbls), run_time=0.5)

        # Drop-out moments along clock_axis (x positions in scene coords).
        dropout_x = [-3.8, -2.6, -1.6]   # firm 1, 2, 3 drop out
        winner_idx = 3                    # firm 4 stays in

        # Build a downstairs ECDF point set on the right.
        ax = Axes(
            x_range=[0, 3, 1], y_range=[0, 1.05, 0.5],
            x_length=4.2, y_length=1.8, tips=False,
            axis_config={"color": GRID, "stroke_width": 1.2,
                          "include_numbers": True, "font_size": 16},
        ).move_to(2.5 * DOWN + 2.0 * RIGHT)
        ax_lbl = Text("c (ref-units)", font=FONT_BODY, color=INK_SOFT)\
            .scale(0.32).next_to(ax, DOWN, buff=0.12)
        self.play(FadeIn(ax), FadeIn(ax_lbl), run_time=0.4)

        # Pregão drop-out points (will appear one by one).
        cost_estimates = [0.65, 1.10, 1.55]
        ecdf_points = VGroup()

        for i, (xd, ce) in enumerate(zip(dropout_x, cost_estimates)):
            # firm dot greys out at clock position xd
            new_pos = clock_axis.get_start() + (xd - clock_axis.get_start()[0]) * RIGHT \
                       + (firm_y[i] - clock_axis.get_start()[1] + 1.5) * UP
            self.play(
                firms[i].animate.move_to(LEFT * (-xd if xd < 0 else xd)
                                          * (-1 if xd < 0 else 1)
                                          + UP * firm_y[i])
                              .set_color(GRID),
                run_time=0.5,
            )
            # mark drop-out price
            mark = Line(LEFT * (-xd) + UP * firm_y[i] + UP * 0.18,
                        LEFT * (-xd) + UP * firm_y[i] + DOWN * 0.18,
                        color=RED_SME, stroke_width=2)
            mark_lbl = Text(f"upper bound on c_{i+1}",
                            font=FONT_BODY, color=RED_SME).scale(0.3)\
                .next_to(mark, DOWN, buff=0.1)
            # add ECDF point on the right
            ecdf_dot = Dot(ax.c2p(ce, (i + 1) / 4),
                            color=RED_SME, radius=0.07)
            ecdf_points.add(ecdf_dot)
            self.play(FadeIn(mark), FadeIn(mark_lbl), FadeIn(ecdf_dot),
                      run_time=0.4)
            self.wait(0.3)

        # Winner reaches end of clock.
        self.play(firms[winner_idx].animate.set_color(GREEN_OK)
                  .scale(1.3), run_time=0.4)
        winner_lbl = Text("winner", font=FONT_BODY, color=GREEN_OK,
                          weight="MEDIUM").scale(0.4)\
            .next_to(firms[winner_idx], RIGHT, buff=0.2)
        self.play(FadeIn(winner_lbl), run_time=0.3)

        # Pregão F_c curve through the ECDF points.
        def fc_pregao(c):
            x = np.clip(c / 3.0, 0, 1)
            return float(1 - (1 - x) ** 2.4)
        curve_pregao = ax.plot(fc_pregao, x_range=[0.05, 2.95],
                               color=RED_SME, stroke_width=2.0)
        self.play(FadeIn(curve_pregao), run_time=0.6)

        # Convite F_c (GPV-inverted), nearly coincident.
        def fc_convite(c):
            x = np.clip(c / 3.0, 0, 1)
            return float(1 - (1 - x) ** 2.5)
        curve_convite = ax.plot(fc_convite, x_range=[0.05, 2.95],
                                color=BLUE_NS, stroke_width=2.0)
        self.play(FadeIn(curve_convite), run_time=0.6)

        legend = VGroup(
            VGroup(Line(ORIGIN, RIGHT * 0.4, color=RED_SME, stroke_width=2),
                   Text(" Pregão drop-out", font=FONT_BODY, color=INK_SOFT)
                   .scale(0.35)).arrange(buff=0.1),
            VGroup(Line(ORIGIN, RIGHT * 0.4, color=BLUE_NS, stroke_width=2),
                   Text(" Convite GPV-inverted", font=FONT_BODY,
                        color=INK_SOFT).scale(0.35)).arrange(buff=0.1),
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.12)\
         .next_to(ax, UP, buff=0.15)
        self.play(FadeIn(legend), run_time=0.4)

        overlay = Text("Validation: two auction formats, one cost distribution.",
                       font=FONT_TITLE, color=GREEN_OK, weight="MEDIUM",
                       slant="ITALIC")\
            .scale(0.5).move_to(3.0 * UP)
        self.play(FadeIn(overlay, shift=0.1 * DOWN), run_time=0.5)

        self.wait(2.0)
        self.play(FadeOut(VGroup(*self.mobjects)), run_time=0.6)
