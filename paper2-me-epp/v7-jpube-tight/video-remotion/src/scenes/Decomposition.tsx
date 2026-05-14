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
import {palette, fonts} from '../lib/theme';

/**
 * Scene 06 — The decomposition centerpiece. 152-second scene structured
 * in four phases that build the headline result: ~74% of the price
 * effect runs through bid behavior (intensive margin), not entry.
 *
 *   A (0-25s)    Two channels framing — extensive vs intensive.
 *   B (25-72s)   S1 / S2 / S3 bar chart. Non-monotonic pattern: S2 > S3 > S1
 *                because endogenous SME entry partially offsets the
 *                restriction.
 *   C (72-115s)  74% donut chart — the climax.
 *   D (115-152s) "Sheltered bidding" + endogenous entry insight + punchline.
 *
 * Numbers sourced from output/tables/tab_v3_bne_decomp.tex (non-pharma row).
 */

const PHASE = {
  A_END: 25,
  B_END: 72,
  C_END: 115,
  D_END: 152,
} as const;

// Canonical scenario indices from tab_v3_bne_decomp.tex (non-pharma).
const S1 = 100;
const S2 = 152; // 1.152 / 0.759 × 100
const S3 = 134; // 1.018 / 0.759 × 100
const INTENSIVE_PCT = 74; // 74.5% rounded
const EXTENSIVE_PCT = 26;

// ============================================================================
// Phase A — Two channels framing
// ============================================================================
const PhaseA: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const exit = interpolate(frame, [(PHASE.A_END - 2) * fps, PHASE.A_END * fps], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <AbsoluteFill
      style={{
        opacity: exit,
        alignItems: 'center',
        justifyContent: 'center',
        pointerEvents: 'none',
      }}
    >
      <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 56}}>
        <Reveal delaySec={0.4}>
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
            The decomposition
          </div>
        </Reveal>
        <Reveal delaySec={1.2}>
          <div
            style={{
              fontFamily: fonts.display,
              fontSize: 64,
              color: palette.ink,
              fontWeight: 600,
              letterSpacing: '-0.025em',
              textAlign: 'center',
              maxWidth: 1500,
              lineHeight: 1.15,
            }}
          >
            The price hike runs through{' '}
            <span style={{color: palette.red}}>two channels.</span>
          </div>
        </Reveal>

        {/* Two side-by-side cards */}
        <div style={{display: 'flex', gap: 64, marginTop: 32}}>
          <Reveal delaySec={4.0} tx={-20}>
            <div
              style={{
                width: 540,
                padding: '40px 36px',
                backgroundColor: palette.surface,
                border: `1px solid ${palette.rule}`,
                borderRadius: 12,
              }}
            >
              <div
                style={{
                  fontFamily: fonts.body,
                  fontSize: 18,
                  color: palette.blue,
                  letterSpacing: '0.16em',
                  textTransform: 'uppercase',
                  fontWeight: 600,
                  marginBottom: 16,
                }}
              >
                Extensive margin
              </div>
              <div
                style={{
                  fontFamily: fonts.display,
                  fontSize: 36,
                  color: palette.ink,
                  fontWeight: 600,
                  letterSpacing: '-0.02em',
                  marginBottom: 16,
                }}
              >
                Who shows up.
              </div>
              <div
                style={{
                  fontFamily: fonts.body,
                  fontSize: 22,
                  color: palette.inkSoft,
                  fontWeight: 400,
                  letterSpacing: '-0.005em',
                  lineHeight: 1.45,
                }}
              >
                Restrict the pool. Fewer firms in the room. Prices rise
                because supply shrinks.
              </div>
            </div>
          </Reveal>
          <Reveal delaySec={5.5} tx={20}>
            <div
              style={{
                width: 540,
                padding: '40px 36px',
                backgroundColor: palette.surface,
                border: `1px solid ${palette.red}`,
                borderRadius: 12,
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
                  marginBottom: 16,
                }}
              >
                Intensive margin
              </div>
              <div
                style={{
                  fontFamily: fonts.display,
                  fontSize: 36,
                  color: palette.ink,
                  fontWeight: 600,
                  letterSpacing: '-0.02em',
                  marginBottom: 16,
                }}
              >
                How they bid.
              </div>
              <div
                style={{
                  fontFamily: fonts.body,
                  fontSize: 22,
                  color: palette.inkSoft,
                  fontWeight: 400,
                  letterSpacing: '-0.005em',
                  lineHeight: 1.45,
                }}
              >
                Sheltered SMEs face only other SMEs. Less pressure on the
                runner-up. Lower bid intensity.
              </div>
            </div>
          </Reveal>
        </div>

        <Reveal delaySec={9.0}>
          <div
            style={{
              fontFamily: fonts.body,
              fontSize: 24,
              color: palette.inkMuted,
              letterSpacing: '0.06em',
              textTransform: 'uppercase',
              fontWeight: 500,
              marginTop: 24,
              fontStyle: 'italic',
            }}
          >
            Which one dominates?
          </div>
        </Reveal>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// Phase B — S1 / S2 / S3 bar chart
// ============================================================================
const PhaseB: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const startSec = PHASE.A_END;
  const enter = interpolate(
    frame,
    [startSec * fps, (startSec + 1.5) * fps],
    [0, 1],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.16, 1, 0.3, 1)},
  );
  const exit = interpolate(
    frame,
    [(PHASE.B_END - 2.5) * fps, PHASE.B_END * fps],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  const opacity = enter * exit;

  // Bar growth animations.
  const s1Width = interpolate(
    frame,
    [(startSec + 2.5) * fps, (startSec + 4.0) * fps],
    [0, S1],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.16, 1, 0.3, 1)},
  );
  const s2Width = interpolate(
    frame,
    [(startSec + 9) * fps, (startSec + 11) * fps],
    [0, S2],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.16, 1, 0.3, 1)},
  );
  const s3Width = interpolate(
    frame,
    [(startSec + 22) * fps, (startSec + 24) * fps],
    [0, S3],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.16, 1, 0.3, 1)},
  );

  // Layout — bars centred on a 920 px canvas; annotation arrows stay in
  // their own vertical lane to the right of the value labels.
  const BAR_LEFT = 420;
  const BAR_TOP = 360;
  const BAR_H = 64;
  const BAR_GAP = 44;
  const PX_PER_PCT = 4.6;
  const VALUE_LANE = 90;   // px reserved for the value label after the bar
  const ARROW_LANE_X = BAR_LEFT + S2 * PX_PER_PCT + VALUE_LANE + 36;

  type Bar = {
    label: string;
    sublabel: string;
    width: number;
    color: string;
    y: number;
  };
  const bars: Bar[] = [
    {label: 'S1', sublabel: 'baseline · open competition', width: s1Width,
      color: palette.inkSoft, y: BAR_TOP},
    {label: 'S2', sublabel: 'restricted · no entry adjustment', width: s2Width,
      color: palette.red, y: BAR_TOP + BAR_H + BAR_GAP},
    {label: 'S3', sublabel: 'restricted + endogenous SME entry', width: s3Width,
      color: palette.amber, y: BAR_TOP + 2 * (BAR_H + BAR_GAP)},
  ];

  return (
    <div style={{opacity, position: 'absolute', inset: 0, pointerEvents: 'none'}}>
      <Reveal delaySec={startSec + 0.5}>
        <div
          style={{
            position: 'absolute',
            top: 180,
            left: 0,
            right: 0,
            textAlign: 'center',
            fontFamily: fonts.body,
            fontSize: 22,
            color: palette.red,
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            fontWeight: 600,
          }}
        >
          Three counterfactual prices
        </div>
      </Reveal>
      <Reveal delaySec={startSec + 1.2}>
        <div
          style={{
            position: 'absolute',
            top: 230,
            left: 0,
            right: 0,
            textAlign: 'center',
            fontFamily: fonts.display,
            fontSize: 44,
            color: palette.ink,
            fontWeight: 500,
            letterSpacing: '-0.02em',
          }}
        >
          What does the auction pay under each regime?
        </div>
      </Reveal>

      <svg width={1920} height={1080} style={{position: 'absolute', inset: 0}}>
        {/* Bars + labels */}
        {bars.map((b) => (
          <g key={b.label}>
            {/* Bar */}
            <rect
              x={BAR_LEFT}
              y={b.y}
              width={b.width * PX_PER_PCT}
              height={BAR_H}
              fill={b.color}
              opacity={0.55}
              rx={3}
            />
            {/* Bar value label */}
            <text
              x={BAR_LEFT + b.width * PX_PER_PCT + 18}
              y={b.y + BAR_H / 2 + 14}
              fontFamily={fonts.display}
              fontSize={42}
              fontWeight={700}
              fill={b.color}
              style={{fontVariantNumeric: 'tabular-nums'}}
            >
              {Math.round(b.width)}
            </text>
            {/* Left-side scenario label */}
            <text
              x={BAR_LEFT - 24}
              y={b.y + BAR_H / 2 - 4}
              textAnchor="end"
              fontFamily={fonts.display}
              fontSize={36}
              fontWeight={700}
              fill={palette.ink}
              style={{fontVariantNumeric: 'tabular-nums'}}
            >
              {b.label}
            </text>
            <text
              x={BAR_LEFT - 24}
              y={b.y + BAR_H / 2 + 26}
              textAnchor="end"
              fontFamily={fonts.body}
              fontSize={16}
              fill={palette.inkMuted}
              fontWeight={500}
              fontStyle="italic"
            >
              {b.sublabel}
            </text>
          </g>
        ))}

        {/* Right-side bracket annotations. Brackets sit in their own
            vertical lane (ARROW_LANE_X) so they don't collide with the
            bar-value labels. Each bracket spans the two row centres it
            connects, with the delta label set off to its right. */}
        {frame >= (startSec + 12) * fps && (() => {
          const op = interpolate(
            frame,
            [(startSec + 12) * fps, (startSec + 13) * fps],
            [0, 1],
            {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
          );
          const y1 = BAR_TOP + BAR_H / 2;
          const y2 = BAR_TOP + BAR_H + BAR_GAP + BAR_H / 2;
          const tipX = ARROW_LANE_X;
          return (
            <g opacity={op}>
              <line x1={tipX} y1={y1} x2={tipX + 14} y2={y1} stroke={palette.red} strokeWidth={1.6} />
              <line x1={tipX + 14} y1={y1} x2={tipX + 14} y2={y2} stroke={palette.red} strokeWidth={1.6} />
              <line x1={tipX + 14} y1={y2} x2={tipX} y2={y2} stroke={palette.red} strokeWidth={1.6} />
              <text
                x={tipX + 30}
                y={(y1 + y2) / 2 - 4}
                fontFamily={fonts.body}
                fontSize={20}
                fontWeight={700}
                fill={palette.red}
                letterSpacing="0.02em"
              >
                +52 pts
              </text>
              <text
                x={tipX + 30}
                y={(y1 + y2) / 2 + 22}
                fontFamily={fonts.body}
                fontSize={16}
                fontWeight={500}
                fill={palette.red}
                letterSpacing="0.02em"
              >
                intensive · sheltered bidding
              </text>
            </g>
          );
        })()}
        {frame >= (startSec + 25) * fps && (() => {
          const op = interpolate(
            frame,
            [(startSec + 25) * fps, (startSec + 26) * fps],
            [0, 1],
            {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
          );
          const y1 = BAR_TOP + BAR_H + BAR_GAP + BAR_H / 2;
          const y2 = BAR_TOP + 2 * (BAR_H + BAR_GAP) + BAR_H / 2;
          const tipX = ARROW_LANE_X;
          return (
            <g opacity={op}>
              <line x1={tipX} y1={y1} x2={tipX + 14} y2={y1} stroke={palette.amber} strokeWidth={1.6} />
              <line x1={tipX + 14} y1={y1} x2={tipX + 14} y2={y2} stroke={palette.amber} strokeWidth={1.6} />
              <line x1={tipX + 14} y1={y2} x2={tipX} y2={y2} stroke={palette.amber} strokeWidth={1.6} />
              <text
                x={tipX + 30}
                y={(y1 + y2) / 2 - 4}
                fontFamily={fonts.body}
                fontSize={20}
                fontWeight={700}
                fill={palette.amber}
                letterSpacing="0.02em"
              >
                −18 pts
              </text>
              <text
                x={tipX + 30}
                y={(y1 + y2) / 2 + 22}
                fontFamily={fonts.body}
                fontSize={16}
                fontWeight={500}
                fill={palette.amber}
                letterSpacing="0.02em"
              >
                extensive · endogenous entry (partial offset)
              </text>
            </g>
          );
        })()}
      </svg>

      {/* Footer label */}
      <Reveal delaySec={startSec + 38}>
        <div
          style={{
            position: 'absolute',
            bottom: 200,
            left: 0,
            right: 0,
            textAlign: 'center',
            fontFamily: fonts.display,
            fontSize: 32,
            color: palette.ink,
            fontWeight: 500,
            letterSpacing: '-0.02em',
            fontStyle: 'italic',
          }}
        >
          The big jump is{' '}
          <span style={{color: palette.red, fontWeight: 600}}>
            S1 → S2.
          </span>{' '}
          Entry only undoes part of it.
        </div>
      </Reveal>
    </div>
  );
};

// ============================================================================
// Phase C — 74% donut climax
// ============================================================================
const PhaseC: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const startSec = PHASE.B_END;
  const enter = interpolate(
    frame,
    [startSec * fps, (startSec + 1.5) * fps],
    [0, 1],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.16, 1, 0.3, 1)},
  );
  const exit = interpolate(
    frame,
    [(PHASE.C_END - 2.5) * fps, PHASE.C_END * fps],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  const opacity = enter * exit;

  // Donut sweep animation
  const sweepProg = interpolate(
    frame,
    [(startSec + 4) * fps, (startSec + 7) * fps],
    [0, 1],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.16, 1, 0.3, 1)},
  );
  const counter = interpolate(
    frame,
    [(startSec + 4) * fps, (startSec + 7) * fps],
    [0, INTENSIVE_PCT],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.16, 1, 0.3, 1)},
  );

  const cx = 760;
  const cy = 540;
  const rOuter = 200;
  const rInner = 130;

  // Sweep arc path: from 12 o'clock, going clockwise
  const angle = -Math.PI / 2 + sweepProg * 2 * Math.PI * (INTENSIVE_PCT / 100);
  const arcLarge = INTENSIVE_PCT / 100 > 0.5 ? 1 : 0;
  const x1 = cx + rOuter * Math.cos(-Math.PI / 2);
  const y1 = cy + rOuter * Math.sin(-Math.PI / 2);
  const x2 = cx + rOuter * Math.cos(angle);
  const y2 = cy + rOuter * Math.sin(angle);
  const x3 = cx + rInner * Math.cos(angle);
  const y3 = cy + rInner * Math.sin(angle);
  const x4 = cx + rInner * Math.cos(-Math.PI / 2);
  const y4 = cy + rInner * Math.sin(-Math.PI / 2);
  const sweepPath = `M ${x1} ${y1} A ${rOuter} ${rOuter} 0 ${arcLarge} 1 ${x2} ${y2} L ${x3} ${y3} A ${rInner} ${rInner} 0 ${arcLarge} 0 ${x4} ${y4} Z`;

  // Extensive arc (the remaining 26%)
  const extOpacity = interpolate(
    frame,
    [(startSec + 7) * fps, (startSec + 8) * fps],
    [0, 1],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  const xa = cx + rOuter * Math.cos(angle);
  const ya = cy + rOuter * Math.sin(angle);
  const xb = cx + rOuter * Math.cos(-Math.PI / 2 - 0.001);
  const yb = cy + rOuter * Math.sin(-Math.PI / 2 - 0.001);
  const xc = cx + rInner * Math.cos(-Math.PI / 2 - 0.001);
  const yc = cy + rInner * Math.sin(-Math.PI / 2 - 0.001);
  const xd = cx + rInner * Math.cos(angle);
  const yd = cy + rInner * Math.sin(angle);
  const extPath = `M ${xa} ${ya} A ${rOuter} ${rOuter} 0 0 1 ${xb} ${yb} L ${xc} ${yc} A ${rInner} ${rInner} 0 0 0 ${xd} ${yd} Z`;

  return (
    <div style={{opacity, position: 'absolute', inset: 0, pointerEvents: 'none'}}>
      <Reveal delaySec={startSec + 0.5}>
        <div
          style={{
            position: 'absolute',
            top: 200,
            left: 0,
            right: 0,
            textAlign: 'center',
            fontFamily: fonts.body,
            fontSize: 22,
            color: palette.red,
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            fontWeight: 600,
          }}
        >
          The headline finding
        </div>
      </Reveal>
      <Reveal delaySec={startSec + 1.5}>
        <div
          style={{
            position: 'absolute',
            top: 260,
            left: 0,
            right: 0,
            textAlign: 'center',
            fontFamily: fonts.display,
            fontSize: 48,
            color: palette.ink,
            fontWeight: 600,
            letterSpacing: '-0.025em',
            lineHeight: 1.15,
          }}
        >
          Most of the price hike comes from how the
          <br />
          surviving firms{' '}
          <span style={{color: palette.red}}>bid</span>
          {' — not from'}{' '}
          <span style={{color: palette.blue}}>who enters.</span>
        </div>
      </Reveal>

      <svg width={1920} height={1080} style={{position: 'absolute', inset: 0}}>
        {/* Background ring */}
        <circle cx={cx} cy={cy} r={rOuter} fill="none" stroke={palette.rule} strokeWidth={2} />
        <circle cx={cx} cy={cy} r={rInner} fill="none" stroke={palette.rule} strokeWidth={2} />

        {/* Intensive arc */}
        <path d={sweepPath} fill={palette.red} opacity={0.92} />

        {/* Extensive arc */}
        <path d={extPath} fill={palette.amber} opacity={extOpacity * 0.92} />

        {/* Center counter */}
        <text
          x={cx}
          y={cy + 8}
          textAnchor="middle"
          fontFamily={fonts.display}
          fontSize={96}
          fontWeight={700}
          fill={palette.red}
          style={{fontVariantNumeric: 'tabular-nums'}}
        >
          {Math.round(counter)}%
        </text>
        <text
          x={cx}
          y={cy + 56}
          textAnchor="middle"
          fontFamily={fonts.body}
          fontSize={18}
          fontWeight={500}
          fill={palette.inkMuted}
          letterSpacing="0.1em"
        >
          INTENSIVE MARGIN
        </text>
      </svg>

      {/* Right-side legend */}
      <div
        style={{
          position: 'absolute',
          left: 1080,
          top: 460,
          display: 'flex',
          flexDirection: 'column',
          gap: 36,
          opacity: extOpacity,
        }}
      >
        <div style={{display: 'flex', alignItems: 'flex-start', gap: 18}}>
          <div
            style={{
              width: 16,
              height: 16,
              backgroundColor: palette.red,
              borderRadius: 4,
              marginTop: 8,
            }}
          />
          <div>
            <div
              style={{
                fontFamily: fonts.display,
                fontSize: 38,
                color: palette.red,
                fontWeight: 700,
                letterSpacing: '-0.02em',
                fontVariantNumeric: 'tabular-nums',
                lineHeight: 1.1,
              }}
            >
              74%
            </div>
            <div
              style={{
                fontFamily: fonts.body,
                fontSize: 24,
                color: palette.ink,
                fontWeight: 500,
                letterSpacing: '-0.005em',
                marginTop: 2,
              }}
            >
              Intensive margin
            </div>
            <div
              style={{
                fontFamily: fonts.body,
                fontSize: 18,
                color: palette.inkMuted,
                fontWeight: 400,
                marginTop: 4,
                fontStyle: 'italic',
              }}
            >
              sheltered bidding
            </div>
          </div>
        </div>

        <div style={{display: 'flex', alignItems: 'flex-start', gap: 18}}>
          <div
            style={{
              width: 16,
              height: 16,
              backgroundColor: palette.amber,
              borderRadius: 4,
              marginTop: 8,
            }}
          />
          <div>
            <div
              style={{
                fontFamily: fonts.display,
                fontSize: 38,
                color: palette.amber,
                fontWeight: 700,
                letterSpacing: '-0.02em',
                fontVariantNumeric: 'tabular-nums',
                lineHeight: 1.1,
              }}
            >
              26%
            </div>
            <div
              style={{
                fontFamily: fonts.body,
                fontSize: 24,
                color: palette.ink,
                fontWeight: 500,
                letterSpacing: '-0.005em',
                marginTop: 2,
              }}
            >
              Extensive margin
            </div>
            <div
              style={{
                fontFamily: fonts.body,
                fontSize: 18,
                color: palette.inkMuted,
                fontWeight: 400,
                marginTop: 4,
                fontStyle: 'italic',
              }}
            >
              entry adjustment (partial offset)
            </div>
          </div>
        </div>
      </div>

      {/* Footer attribution */}
      <Reveal delaySec={startSec + 32}>
        <div
          style={{
            position: 'absolute',
            bottom: 200,
            left: 0,
            right: 0,
            textAlign: 'center',
            fontFamily: fonts.body,
            fontSize: 18,
            color: palette.inkMuted,
            letterSpacing: '0.06em',
            textTransform: 'uppercase',
            fontWeight: 500,
          }}
        >
          source · BNE counterfactual, non-pharma · tab. 6 of the paper
        </div>
      </Reveal>
    </div>
  );
};

// ============================================================================
// Phase D — Sheltered bidding insight + endogenous entry twist
// ============================================================================
const PhaseD: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const startSec = PHASE.C_END;
  const enter = interpolate(
    frame,
    [startSec * fps, (startSec + 1.5) * fps],
    [0, 1],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.16, 1, 0.3, 1)},
  );
  const exit = interpolate(
    frame,
    [(PHASE.D_END - 2) * fps, PHASE.D_END * fps],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  const opacity = enter * exit;

  return (
    <div style={{opacity, position: 'absolute', inset: 0, pointerEvents: 'none'}}>
      {/* Center pull-quote */}
      <Reveal delaySec={startSec + 1.0}>
        <div
          style={{
            position: 'absolute',
            top: 280,
            left: 0,
            right: 0,
            textAlign: 'center',
            fontFamily: fonts.display,
            fontSize: 56,
            color: palette.ink,
            fontWeight: 500,
            letterSpacing: '-0.025em',
            lineHeight: 1.25,
            maxWidth: 1500,
            marginInline: 'auto',
            fontStyle: 'italic',
          }}
        >
          When SMEs are{' '}
          <span style={{color: palette.red, fontWeight: 600, fontStyle: 'normal'}}>
            sheltered
          </span>{' '}
          from the giants,
          <br />
          the shadow of the giant is gone.
        </div>
      </Reveal>

      <Reveal delaySec={startSec + 6.0}>
        <div
          style={{
            position: 'absolute',
            top: 510,
            left: 0,
            right: 0,
            textAlign: 'center',
            fontFamily: fonts.body,
            fontSize: 28,
            color: palette.inkSoft,
            fontWeight: 400,
            letterSpacing: '-0.005em',
            lineHeight: 1.4,
            maxWidth: 1300,
            marginInline: 'auto',
          }}
        >
          They don't have to fight as hard.
          <br />
          The runner-up is slower.
          <br />
          So is the winner.
        </div>
      </Reveal>

      {/* The endogenous entry twist */}
      <Reveal delaySec={startSec + 18.0}>
        <div
          style={{
            position: 'absolute',
            bottom: 180,
            left: 0,
            right: 0,
            textAlign: 'center',
          }}
        >
          <div
            style={{
              fontFamily: fonts.body,
              fontSize: 18,
              color: palette.amber,
              letterSpacing: '0.16em',
              textTransform: 'uppercase',
              fontWeight: 600,
              marginBottom: 12,
            }}
          >
            The twist
          </div>
          <div
            style={{
              fontFamily: fonts.display,
              fontSize: 30,
              color: palette.ink,
              fontWeight: 500,
              letterSpacing: '-0.02em',
              lineHeight: 1.3,
              maxWidth: 1400,
              marginInline: 'auto',
            }}
          >
            A protected sandbox creates a gold rush — new SMEs enter,
            <br />
            attenuating the shock by{' '}
            <span style={{color: palette.amber, fontWeight: 600}}>
              50–60%.
            </span>
          </div>
        </div>
      </Reveal>
    </div>
  );
};

// ============================================================================
// Main scene
// ============================================================================
export const Decomposition: React.FC = () => {
  return (
    <Frame>
      <Chrome />
      <PhaseA />
      <PhaseB />
      <PhaseC />
      <PhaseD />
    </Frame>
  );
};
