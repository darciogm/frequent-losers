import React from 'react';
import {
  AbsoluteFill,
  useCurrentFrame,
  interpolate,
  spring,
  useVideoConfig,
  Easing,
} from 'remotion';
import {Frame} from '../components/Frame';
import {Chrome} from '../components/Chrome';
import {Reveal} from '../components/Reveal';
import {palette, fonts, sizes} from '../lib/theme';

/**
 * Scene 00 — Cold open. The hero figure carries the visual weight; the
 * editorial chrome (eyebrow label, hairline rules, episode marker) gives
 * the frame the density of a long-form magazine open. Calibrated to the
 * 54-second NotebookLM block.
 */

const formatNumber = (n: number) =>
  new Intl.NumberFormat('en-US').format(Math.round(n));

export const ColdOpen: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  // Counter rolls 0 → 85 between t=0.6s and t=2.4s with Bezier ease-out.
  const counter = interpolate(frame, [fps * 0.6, fps * 2.4], [0, 85], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });

  // Hero block enter spring.
  const heroEnter = spring({
    frame,
    fps,
    config: {damping: 200, stiffness: 80, mass: 0.6},
  });

  // Final exit fade — last 4 s.
  const exitOpacity = interpolate(
    frame,
    [fps * 50, fps * 54],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );

  // Subtle paper-grain — animated ever so slightly, at <2% opacity.
  const grain = (frame % 7) / 700;

  return (
    <Frame>
      {/* Faint paper grain background */}
      <AbsoluteFill
        style={{
          backgroundImage:
            'radial-gradient(circle at 50% 30%, rgba(167,38,58,0.025), transparent 60%)',
          opacity: 1 - grain,
        }}
      />

      {/* Persistent editorial chrome */}
      <Chrome />

      {/* Hero block, slightly above center */}
      <AbsoluteFill
        style={{
          alignItems: 'center',
          justifyContent: 'center',
          opacity: exitOpacity,
        }}
      >
        <div
          style={{
            transform: `translateY(${(1 - heroEnter) * 18 - 60}px)`,
            opacity: heroEnter,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: 64,
          }}
        >
          {/* Eyebrow above hero */}
          <Reveal delaySec={0.4}>
            <div
              style={{
                fontFamily: fonts.body,
                fontSize: 26,
                color: palette.inkSoft,
                fontWeight: 500,
                letterSpacing: '-0.005em',
              }}
            >
              How much did one Brazilian procurement rule cost?
            </div>
          </Reveal>

          {/* Hero figure */}
          <div
            style={{
              fontFamily: fonts.display,
              fontWeight: 700,
              fontSize: sizes.hero,
              color: palette.red,
              letterSpacing: '-0.045em',
              fontVariantNumeric: 'tabular-nums',
              fontFeatureSettings: '"tnum" 1',
              lineHeight: 1,
              display: 'flex',
              alignItems: 'baseline',
              gap: 22,
            }}
          >
            <span
              style={{
                fontSize: sizes.hero * 0.58,
                fontWeight: 600,
                opacity: 0.92,
              }}
            >
              R$
            </span>
            <span style={{minWidth: '2ch', textAlign: 'right'}}>
              {formatNumber(counter)}
            </span>
            <span
              style={{
                fontSize: sizes.hero * 0.36,
                fontWeight: 500,
                color: palette.red,
                opacity: interpolate(frame, [fps * 2.0, fps * 2.6], [0, 1], {
                  extrapolateLeft: 'clamp',
                  extrapolateRight: 'clamp',
                }),
              }}
            >
              million
            </span>
          </div>

          {/* Hairline divider */}
          <div
            style={{
              width: 96,
              height: 1,
              backgroundColor: palette.rule,
              opacity: interpolate(frame, [fps * 2.2, fps * 2.8], [0, 1], {
                extrapolateLeft: 'clamp',
                extrapolateRight: 'clamp',
              }),
            }}
          />

          {/* Sublines */}
          <div
            style={{
              display: 'flex',
              flexDirection: 'column',
              gap: 14,
              alignItems: 'center',
              textAlign: 'center',
              fontFamily: fonts.body,
              fontSize: sizes.body,
              color: palette.inkSoft,
              fontWeight: 400,
              letterSpacing: '-0.005em',
              lineHeight: 1.4,
            }}
          >
            <Reveal delaySec={2.8}>
              <span>In 18 months. In São Paulo state hospitals.</span>
            </Reveal>
            <Reveal delaySec={3.4}>
              <span style={{color: palette.inkMuted}}>
                On gauze, syringes, and pills.
              </span>
            </Reveal>
          </div>
        </div>
      </AbsoluteFill>

    </Frame>
  );
};
