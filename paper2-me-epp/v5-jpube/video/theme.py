"""Shared palette, typography, and helpers for the Cost-of-Inclusion video.

Palette mirrors the paper's grayscale figures plus two accents matching the
mkdocs site (red-tile for SME / treatment, steel blue for non-SME / control).
"""

from __future__ import annotations

from manim import (
    Mobject, VGroup, Text, MarkupText, Tex, MathTex, Rectangle,
    Line, FadeIn, FadeOut, Write, Create, AnimationGroup,
    UP, DOWN, LEFT, RIGHT, ORIGIN, config,
)

# --- Colors --------------------------------------------------------------
INK         = "#111111"   # primary text
INK_SOFT    = "#3a3a3a"   # secondary text
PAPER       = "#fafafa"   # background
GRID        = "#cfcfcf"   # axes, ticks, table rules
RED_SME     = "#a7263a"   # treatment, SME, headline numbers
BLUE_NS     = "#2c4a6b"   # control, non-SME
GREEN_OK    = "#2f6b3b"   # validation, "non-rejection"
AMBER_WARN  = "#b8801a"   # alerts, MCPF dial
BG          = PAPER

# --- Typography ----------------------------------------------------------
FONT_BODY   = "Inter"             # falls back to system sans if missing
FONT_TITLE  = "Inter"
FONT_MONO   = "JetBrains Mono"
FONT_MATH   = None                # MathTex/Tex use the LaTeX stack

SIZE_HEADER = 22
SIZE_BODY   = 32
SIZE_LARGE  = 48
SIZE_HERO   = 84

# --- Layout --------------------------------------------------------------
HEADER_Y      = 3.6   # persistent paper-title strip docks here
SAFE_LEFT     = -6.5
SAFE_RIGHT    = 6.5
SAFE_TOP      = 3.4
SAFE_BOTTOM   = -3.4


def header_strip(title: str = "The Cost of Inclusion — Genicolo-Martins (2026)") -> Mobject:
    """Sticky header that docks at the top after Scene 1."""
    txt = Text(title, font=FONT_HEADER if False else FONT_BODY,
               color=INK_SOFT, weight="MEDIUM").scale(0.35)
    txt.to_corner(UP + LEFT).shift(0.2 * RIGHT + 0.05 * DOWN)
    rule = Line(txt.get_left() + 1.0 * DOWN * 0.05,
                txt.get_right() + 1.0 * DOWN * 0.05,
                color=GRID, stroke_width=0.5)
    return VGroup(txt, rule)


def title_card(line: str, sub: str | None = None) -> VGroup:
    """Centered title block, used in Scene 1 and as section bumpers."""
    main = Text(line, font=FONT_TITLE, color=INK, weight="SEMIBOLD")\
        .scale(SIZE_LARGE / 36)
    group = VGroup(main)
    if sub:
        sl = Text(sub, font=FONT_BODY, color=INK_SOFT).scale(SIZE_BODY / 36)
        sl.next_to(main, DOWN, buff=0.35)
        group.add(sl)
    group.move_to(ORIGIN)
    return group


def hero_number(value: str, suffix: str | None = None,
                color: str = RED_SME) -> VGroup:
    """Big single-figure overlay for cold open and key-stat moments."""
    n = Text(value, font=FONT_TITLE, color=color, weight="BOLD")\
        .scale(SIZE_HERO / 36)
    g = VGroup(n)
    if suffix:
        s = Text(suffix, font=FONT_BODY, color=INK_SOFT).scale(SIZE_BODY / 36)
        s.next_to(n, DOWN, buff=0.5)
        g.add(s)
    g.move_to(ORIGIN)
    return g


def overlay_quote(text: str, position=ORIGIN, italic: bool = True,
                  color: str = INK) -> Text:
    """Pull-quote overlay used to emphasize a punchline."""
    weight = "MEDIUM"
    t = Text(text, font=FONT_TITLE, slant="ITALIC" if italic else "NORMAL",
             weight=weight, color=color, line_spacing=1.15)\
        .scale(SIZE_BODY / 36)
    t.move_to(position)
    return t


def fade_swap(scene, old: Mobject, new: Mobject, run_time: float = 0.6):
    """Cross-fade helper used between scenes and within long scenes."""
    scene.play(
        AnimationGroup(FadeOut(old), FadeIn(new), lag_ratio=0.4),
        run_time=run_time,
    )


# Configure Manim defaults centrally so per-scene files stay focused on
# storytelling, not boilerplate.
def configure_manim() -> None:
    config.background_color = BG
    config.frame_width = 14.22
    config.frame_height = 8.0
    config.pixel_width = 1920
    config.pixel_height = 1080
    config.frame_rate = 30
