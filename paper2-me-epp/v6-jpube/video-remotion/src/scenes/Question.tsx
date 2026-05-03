import React from 'react';
import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  Easing,
  spring,
} from 'remotion';
import {Frame} from '../components/Frame';
import {Chrome} from '../components/Chrome';
import {Reveal} from '../components/Reveal';
import {palette, fonts, sizes} from '../lib/theme';

/**
 * Scene 01 — The question. Three phases over the 80-second NotebookLM
 * block: (1) full paper title card; (2) three mission questions stacked
 * left-aligned; (3) one-line bridge into the natural-experiment scene.
 */
export const Question: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  // Title card holds for ~14s, then dissolves out as questions enter.
  const titleEnter = spring({
    frame,
    fps,
    config: {damping: 200, stiffness: 80, mass: 0.6},
  });
  const titleExit = interpolate(frame, [fps * 14, fps * 16], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });
  const titleOpacity = titleEnter * titleExit;

  // Bridge line ("Three questions. One experiment.") at t=64s.
  const bridgeEnter = interpolate(frame, [fps * 64, fps * 66], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });
  const bridgeExit = interpolate(frame, [fps * 78, fps * 80], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const bridgeOpacity = bridgeEnter * bridgeExit;

  // Questions exit during the bridge.
  const questionsExit = interpolate(frame, [fps * 64, fps * 66], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <Frame>
      <Chrome />

      {/* Phase 1 — title card */}
      <AbsoluteFill
        style={{
          alignItems: 'center',
          justifyContent: 'center',
          opacity: titleOpacity,
          pointerEvents: 'none',
        }}
      >
        <div
          style={{
            transform: `translateY(${(1 - titleEnter) * 18}px)`,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: 36,
          }}
        >
          {/* Eyebrow above title */}
          <div
            style={{
              fontFamily: fonts.body,
              fontSize: 22,
              color: palette.inkMuted,
              letterSpacing: '0.18em',
              textTransform: 'uppercase',
              fontWeight: 500,
            }}
          >
            Working paper · Insper · 2026
          </div>

          {/* Paper title */}
          <div
            style={{
              fontFamily: fonts.display,
              fontSize: sizes.display,
              fontWeight: 700,
              color: palette.ink,
              letterSpacing: '-0.035em',
              lineHeight: 1.05,
              textAlign: 'center',
              maxWidth: 1500,
            }}
          >
            The Cost of Inclusion
          </div>

          {/* Subtitle */}
          <div
            style={{
              fontFamily: fonts.body,
              fontSize: 38,
              fontWeight: 400,
              color: palette.inkSoft,
              letterSpacing: '-0.01em',
              lineHeight: 1.3,
              textAlign: 'center',
              maxWidth: 1300,
            }}
          >
            Decomposing Bidder Exclusion
            <br />
            in Public Procurement
          </div>

          {/* Hairline */}
          <div
            style={{
              width: 96,
              height: 1,
              backgroundColor: palette.rule,
              marginTop: 18,
            }}
          />

          {/* Byline */}
          <div
            style={{
              fontFamily: fonts.body,
              fontSize: 22,
              color: palette.inkMuted,
              letterSpacing: '0.02em',
              fontWeight: 500,
            }}
          >
            Darcio Genicolo-Martins
          </div>
        </div>
      </AbsoluteFill>

      {/* Phase 2 — three mission questions */}
      <AbsoluteFill
        style={{
          alignItems: 'flex-start',
          justifyContent: 'center',
          paddingLeft: 240,
          paddingRight: 240,
          opacity: questionsExit,
          pointerEvents: 'none',
        }}
      >
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            gap: 56,
            width: '100%',
            maxWidth: 1400,
          }}
        >
          <Reveal delaySec={17}>
            <div
              style={{
                fontFamily: fonts.body,
                fontSize: 20,
                color: palette.red,
                letterSpacing: '0.18em',
                textTransform: 'uppercase',
                fontWeight: 600,
                marginBottom: 24,
              }}
            >
              Three questions
            </div>
          </Reveal>

          {[
            {
              n: '01',
              text: 'How much does it cost?',
              delay: 19,
            },
            {
              n: '02',
              text: 'Why does it cost so much?',
              delay: 27,
            },
            {
              n: '03',
              text: 'Can governments do this better?',
              delay: 38,
            },
          ].map((q) => (
            <Reveal key={q.n} delaySec={q.delay} ty={20}>
              <div
                style={{
                  display: 'flex',
                  alignItems: 'baseline',
                  gap: 48,
                  borderTop: `1px solid ${palette.rule}`,
                  paddingTop: 24,
                }}
              >
                <span
                  style={{
                    fontFamily: fonts.display,
                    fontSize: 44,
                    color: palette.red,
                    fontWeight: 600,
                    fontVariantNumeric: 'tabular-nums',
                    minWidth: 80,
                  }}
                >
                  {q.n}
                </span>
                <span
                  style={{
                    fontFamily: fonts.display,
                    fontSize: 56,
                    color: palette.ink,
                    fontWeight: 500,
                    letterSpacing: '-0.025em',
                    lineHeight: 1.15,
                  }}
                >
                  {q.text}
                </span>
              </div>
            </Reveal>
          ))}
        </div>
      </AbsoluteFill>

      {/* Phase 3 — bridge into next scene */}
      <AbsoluteFill
        style={{
          alignItems: 'center',
          justifyContent: 'center',
          opacity: bridgeOpacity,
          pointerEvents: 'none',
        }}
      >
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: 32,
          }}
        >
          <div
            style={{
              fontFamily: fonts.body,
              fontSize: 22,
              color: palette.red,
              letterSpacing: '0.18em',
              textTransform: 'uppercase',
              fontWeight: 600,
            }}
          >
            One natural experiment
          </div>
          <div
            style={{
              fontFamily: fonts.display,
              fontSize: 64,
              color: palette.ink,
              fontWeight: 500,
              letterSpacing: '-0.025em',
              textAlign: 'center',
              lineHeight: 1.15,
              maxWidth: 1400,
            }}
          >
            São Paulo, Brazil.
            <br />
            <span style={{color: palette.red}}>March 2018.</span>
          </div>
        </div>
      </AbsoluteFill>
    </Frame>
  );
};
