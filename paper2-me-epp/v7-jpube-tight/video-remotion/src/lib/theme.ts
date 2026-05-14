/**
 * Editorial design system for The Cost of Inclusion explainer.
 *
 * Palette mirrors the published paper's grayscale figures plus two
 * accents matching the mkdocs site (red-tile for treatment / SME,
 * steel blue for control / non-SME). Typography pairs Inter for body
 * (Vercel / Stripe / Linear-grade neutral sans) with Roboto Slab for
 * editorial display (numerals, hero figures).
 */

export const palette = {
  paper:    '#fafafa',  // background, off-white with warmth
  ink:      '#0d0d0d',  // primary text — almost black, never #000
  inkSoft:  '#3a3a3a',  // secondary text
  inkMuted: '#7a7a7a',  // tertiary, captions, axis labels
  rule:     '#dcdcdc',  // hairlines, dividers, table rules
  surface:  '#f0eeea',  // tinted surface for cards / aside boxes
  red:      '#a7263a',  // SME / treatment / red-tile from site
  redSoft:  '#e9c4cb',  // 20% tint for backgrounds
  blue:     '#2c4a6b',  // non-SME / control / steel
  blueSoft: '#cfd8e3',
  amber:    '#b8801a',  // alerts, MCPF dial, partial offsets
  green:    '#2f6b3b',  // validation, "non-rejection"
} as const;

// Imports the Google Fonts loaders as a side-effect so the faces are
// registered before any scene starts rendering.
import {fontFamilies} from './fonts';

export const fonts = {
  body:    `"${fontFamilies.body}", system-ui, -apple-system, sans-serif`,
  display: `"${fontFamilies.display}", "${fontFamilies.body}", serif`,
  mono:    `"${fontFamilies.mono}", ui-monospace, monospace`,
} as const;

export const sizes = {
  hero:    160,   // cold-open big number
  display: 96,    // section titles
  large:   54,    // cena heading
  body:    36,    // narration overlay
  caption: 26,    // secondary
  micro:   20,    // axis labels, tiny
} as const;

/**
 * Premium easing curve — Vercel / Linear / iOS (cubic-bezier 0.16, 1, 0.3, 1).
 * Quick start, slow settle. Use for FadeIn / TranslateIn.
 */
export const ease = {
  out:    [0.16, 1, 0.3, 1] as const,
  inOut:  [0.65, 0, 0.35, 1] as const,
  in:     [0.7, 0, 0.84, 0] as const,
};

/**
 * Standard 1920x1080 frame. Safe area mirrors a 12-column editorial grid.
 */
export const layout = {
  width:    1920,
  height:   1080,
  margin:   120,
  gutter:   24,
  columns:  12,
  fps:      60,
} as const;

/** Convert seconds to frames at the project's frame rate. */
export const sec = (n: number) => Math.round(n * layout.fps);
