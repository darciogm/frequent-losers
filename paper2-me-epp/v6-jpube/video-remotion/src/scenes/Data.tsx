import React from 'react';
import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  Easing,
} from 'remotion';
import {Frame} from '../components/Frame';
import {Chrome} from '../components/Chrome';
import {Reveal} from '../components/Reveal';
import {palette, fonts, sizes} from '../lib/theme';

/**
 * Scene 03 — Sample funnel. 43-second scene, three left-to-right stages
 * tracing the data path from the raw BEC platform extract to the
 * 97,993-auction structural sample, with a Pre/Post split bar at the end.
 */

const formatNumber = (n: number) =>
  new Intl.NumberFormat('en-US').format(Math.round(n));

const Counter: React.FC<{
  from: number;
  to: number;
  startSec: number;
  durSec: number;
  fontSize: number;
  color: string;
}> = ({from, to, startSec, durSec, fontSize, color}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const v = interpolate(
    frame,
    [startSec * fps, (startSec + durSec) * fps],
    [from, to],
    {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
      easing: Easing.bezier(0.16, 1, 0.3, 1),
    },
  );
  return (
    <span
      style={{
        fontFamily: fonts.display,
        fontSize,
        color,
        fontWeight: 700,
        letterSpacing: '-0.04em',
        fontVariantNumeric: 'tabular-nums',
        lineHeight: 1,
      }}
    >
      {formatNumber(v)}
    </span>
  );
};

export const Data: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  // Pre/Post split bar reveal at t=32s.
  const splitProg = interpolate(frame, [32 * fps, 35 * fps], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });

  return (
    <Frame>
      <Chrome />

      {/* Phase 1 — BEC source intro (0–10s) */}
      <AbsoluteFill
        style={{
          alignItems: 'center',
          justifyContent: 'flex-start',
          paddingTop: 220,
        }}
      >
        <Reveal delaySec={0.4}>
          <div
            style={{
              fontFamily: fonts.body,
              fontSize: 22,
              color: palette.red,
              letterSpacing: '0.18em',
              textTransform: 'uppercase',
              fontWeight: 600,
              marginBottom: 24,
              textAlign: 'center',
            }}
          >
            The data
          </div>
        </Reveal>

        <Reveal delaySec={1.2}>
          <div
            style={{
              fontFamily: fonts.display,
              fontSize: 56,
              color: palette.ink,
              fontWeight: 600,
              letterSpacing: '-0.02em',
              lineHeight: 1.1,
              textAlign: 'center',
            }}
          >
            Bolsa Eletrônica de Compras{' '}
            <span style={{color: palette.inkMuted, fontWeight: 500}}>(BEC)</span>
          </div>
        </Reveal>

        <Reveal delaySec={2.8}>
          <div
            style={{
              fontFamily: fonts.body,
              fontSize: 26,
              color: palette.inkSoft,
              fontWeight: 400,
              letterSpacing: '-0.005em',
              marginTop: 18,
              textAlign: 'center',
            }}
          >
            São Paulo's electronic procurement platform · since 2005
          </div>
        </Reveal>
      </AbsoluteFill>

      {/* Phase 2 — funnel: raw → filters → structural sample */}
      <AbsoluteFill
        style={{
          alignItems: 'center',
          justifyContent: 'center',
          paddingTop: 80,
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 80,
            width: '100%',
            justifyContent: 'center',
          }}
        >
          {/* Source: 3,700,000 */}
          <Reveal delaySec={6.0}>
            <div
              style={{
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: 14,
                minWidth: 360,
              }}
            >
              <div
                style={{
                  fontFamily: fonts.body,
                  fontSize: 18,
                  color: palette.inkMuted,
                  letterSpacing: '0.16em',
                  textTransform: 'uppercase',
                  fontWeight: 500,
                }}
              >
                Raw extract
              </div>
              <Counter
                from={0}
                to={3700000}
                startSec={6.5}
                durSec={2.0}
                fontSize={84}
                color={palette.inkSoft}
              />
              <div
                style={{
                  fontFamily: fonts.body,
                  fontSize: 22,
                  color: palette.inkSoft,
                  fontWeight: 500,
                  letterSpacing: '-0.005em',
                }}
              >
                observations
              </div>
            </div>
          </Reveal>

          {/* Arrow + filter chips */}
          <Reveal delaySec={11.0}>
            <div
              style={{
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: 18,
                minWidth: 280,
              }}
            >
              {[
                'Group 65 only',
                'Pregão only',
                'Mar 2017 – Aug 2019',
              ].map((label, i) => (
                <Reveal key={label} delaySec={11.5 + i * 0.7}>
                  <div
                    style={{
                      fontFamily: fonts.body,
                      fontSize: 20,
                      color: palette.inkSoft,
                      backgroundColor: palette.surface,
                      border: `1px solid ${palette.rule}`,
                      padding: '10px 22px',
                      borderRadius: 999,
                      fontWeight: 500,
                      letterSpacing: '-0.005em',
                    }}
                  >
                    {label}
                  </div>
                </Reveal>
              ))}
            </div>
          </Reveal>

          {/* Sample: 97,993 */}
          <Reveal delaySec={16.0}>
            <div
              style={{
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: 14,
                minWidth: 360,
              }}
            >
              <div
                style={{
                  fontFamily: fonts.body,
                  fontSize: 18,
                  color: palette.red,
                  letterSpacing: '0.16em',
                  textTransform: 'uppercase',
                  fontWeight: 600,
                }}
              >
                Structural sample
              </div>
              <Counter
                from={0}
                to={97993}
                startSec={16.5}
                durSec={2.0}
                fontSize={84}
                color={palette.red}
              />
              <div
                style={{
                  fontFamily: fonts.body,
                  fontSize: 22,
                  color: palette.ink,
                  fontWeight: 500,
                  letterSpacing: '-0.005em',
                }}
              >
                distinct auctions
              </div>
            </div>
          </Reveal>
        </div>
      </AbsoluteFill>

      {/* Phase 3 — Pre/Post split bar (t=32s onward) */}
      <AbsoluteFill
        style={{
          alignItems: 'center',
          justifyContent: 'flex-end',
          paddingBottom: 220,
        }}
      >
        <div style={{opacity: splitProg, width: 800}}>
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'baseline',
              marginBottom: 14,
              fontFamily: fonts.body,
              fontSize: 20,
              fontWeight: 500,
              color: palette.inkSoft,
            }}
          >
            <span style={{color: palette.blue, fontWeight: 600}}>
              Pre · 48,997
            </span>
            <span
              style={{
                color: palette.inkMuted,
                fontSize: 16,
                letterSpacing: '0.1em',
                textTransform: 'uppercase',
              }}
            >
              Half before, half after
            </span>
            <span style={{color: palette.red, fontWeight: 600}}>
              Post · 48,996
            </span>
          </div>
          {/* Split bar */}
          <div
            style={{
              display: 'flex',
              height: 14,
              borderRadius: 7,
              overflow: 'hidden',
              border: `1px solid ${palette.rule}`,
            }}
          >
            <div
              style={{
                flex: 1,
                background: palette.blue,
                opacity: 0.85,
              }}
            />
            <div
              style={{
                flex: 1,
                background: palette.red,
                opacity: 0.85,
              }}
            />
          </div>
        </div>
      </AbsoluteFill>
    </Frame>
  );
};
