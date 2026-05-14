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
 * Scene 04 — The model in one line. 177-second scene structured in
 * four phases:
 *   A (0-22s)   Pregão definition.
 *   B (22-65s)  Descending-clock visualization — five bidders, clock falls,
 *               bidders drop out one by one as the clock crosses their costs.
 *   C (65-115s) Vickrey logic — zoom on winner vs runner-up cost gap;
 *               winning price = runner-up's cost, not winner's.
 *   D (115-177s) Running-race analogy + the policy punchline.
 */

const PHASE = {
  A_END: 22,
  B_END: 65,
  C_END: 115,
  D_END: 177,
} as const;

// ---- Chart geometry (Phase B/C) ------------------------------------------
const CHART_LEFT = 280;
const CHART_TOP = 240;
const CHART_W = 920;
const CHART_H = 560;
const PRICE_MAX = 1.5;
const PRICE_MIN = 0.0;

// Y axis: high price at top
const yPrice = (p: number) =>
  CHART_TOP + ((PRICE_MAX - p) / (PRICE_MAX - PRICE_MIN)) * CHART_H;
const xTime = (t: number) => CHART_LEFT + t * CHART_W; // t in [0..1]

// Bidders ordered top to bottom: highest cost first.
// Winner is bidder #5 (lowest cost = 0.4); runner-up is bidder #4 (cost 0.6).
type Bidder = {name: string; cost: number; dropOutT: number};
const BIDDERS: Bidder[] = [
  {name: 'Firm 1', cost: 1.20, dropOutT: 0.18},
  {name: 'Firm 2', cost: 1.00, dropOutT: 0.32},
  {name: 'Firm 3', cost: 0.80, dropOutT: 0.48},
  {name: 'Firm 4', cost: 0.60, dropOutT: 0.66},   // runner-up
  {name: 'Firm 5', cost: 0.40, dropOutT: 1.00},   // winner — never drops
];
const WINNING_PRICE = 0.62; // just below runner-up's cost
const T_AT_PRICE = (p: number) => 1 - (p - PRICE_MIN) / (PRICE_MAX - PRICE_MIN); // clock falls linearly

// ============================================================================
// Phase A — Pregão definition
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
        alignItems: 'center',
        justifyContent: 'center',
        opacity: exit,
        pointerEvents: 'none',
      }}
    >
      <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 28}}>
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
            The auction
          </div>
        </Reveal>
        <Reveal delaySec={1.2}>
          <div
            style={{
              fontFamily: fonts.display,
              fontSize: 96,
              color: palette.ink,
              fontWeight: 700,
              letterSpacing: '-0.035em',
              fontStyle: 'italic',
            }}
          >
            Pregão
          </div>
        </Reveal>
        <Reveal delaySec={2.6}>
          <div
            style={{
              fontFamily: fonts.body,
              fontSize: 32,
              color: palette.inkSoft,
              fontWeight: 400,
              letterSpacing: '-0.005em',
              textAlign: 'center',
              maxWidth: 1100,
            }}
          >
            Brazil's electronic{' '}
            <span style={{color: palette.red, fontWeight: 600}}>
              descending-clock
            </span>{' '}
            reverse auction.
          </div>
        </Reveal>
        <Reveal delaySec={5.0}>
          <div
            style={{
              fontFamily: fonts.body,
              fontSize: 26,
              color: palette.inkMuted,
              fontWeight: 400,
              letterSpacing: '-0.005em',
              textAlign: 'center',
              maxWidth: 1100,
              marginTop: 24,
              lineHeight: 1.4,
            }}
          >
            The buyer sets a ceiling. Suppliers undercut each other until one
            remains willing to sell.
          </div>
        </Reveal>
        <Reveal delaySec={11.0}>
          <div
            style={{
              fontFamily: fonts.body,
              fontSize: 22,
              color: palette.inkMuted,
              letterSpacing: '0.06em',
              textTransform: 'uppercase',
              fontWeight: 500,
              marginTop: 56,
              fontStyle: 'italic',
            }}
          >
            think reverse eBay — price goes down
          </div>
        </Reveal>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// Phase B — descending clock with five bidders
// ============================================================================
const PhaseB: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const startSec = PHASE.A_END;
  const enter = interpolate(
    frame,
    [startSec * fps, (startSec + 1.2) * fps],
    [0, 1],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.16, 1, 0.3, 1)},
  );
  const exit = interpolate(
    frame,
    [(PHASE.B_END - 3) * fps, PHASE.B_END * fps],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  const opacity = enter * exit;

  // Clock progress: starts after axes/bidders are drawn (~startSec+5s)
  // and descends over ~25 seconds, ending at the winning price (0.62).
  const clockStart = startSec + 6;
  const clockEnd = startSec + 30;
  const clockT = interpolate(frame, [clockStart * fps, clockEnd * fps], [0, T_AT_PRICE(WINNING_PRICE)], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.bezier(0.65, 0, 0.35, 1),
  });
  const currentPrice = PRICE_MAX - clockT * (PRICE_MAX - PRICE_MIN);

  return (
    <div style={{opacity, position: 'absolute', inset: 0}}>
      {/* Title */}
      <Reveal delaySec={startSec + 0.5}>
        <div
          style={{
            position: 'absolute',
            top: 140,
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
          Five bidders. One clock.
        </div>
      </Reveal>

      <svg width={1920} height={1080} style={{position: 'absolute', inset: 0, pointerEvents: 'none'}}>
        {/* Y-axis label */}
        <text
          x={CHART_LEFT - 100}
          y={CHART_TOP + CHART_H / 2}
          fill={palette.inkMuted}
          fontFamily={fonts.body}
          fontSize={18}
          fontWeight={500}
          letterSpacing="0.1em"
          transform={`rotate(-90, ${CHART_LEFT - 100}, ${CHART_TOP + CHART_H / 2})`}
          textAnchor="middle"
        >
          PRICE (R$ / unit)
        </text>

        {/* X-axis label */}
        <text
          x={CHART_LEFT + CHART_W / 2}
          y={CHART_TOP + CHART_H + 50}
          fill={palette.inkMuted}
          fontFamily={fonts.body}
          fontSize={18}
          fontWeight={500}
          letterSpacing="0.1em"
          textAnchor="middle"
        >
          TIME →
        </text>

        {/* Y-axis ticks */}
        {[0.0, 0.5, 1.0, 1.5].map((p) => (
          <g key={p}>
            <line
              x1={CHART_LEFT - 8}
              y1={yPrice(p)}
              x2={CHART_LEFT}
              y2={yPrice(p)}
              stroke={palette.inkMuted}
              strokeWidth={1}
            />
            <text
              x={CHART_LEFT - 18}
              y={yPrice(p) + 6}
              fontFamily={fonts.body}
              fontSize={16}
              fill={palette.inkMuted}
              textAnchor="end"
              style={{fontVariantNumeric: 'tabular-nums'}}
            >
              {p.toFixed(1)}
            </text>
          </g>
        ))}

        {/* Y axis */}
        <line
          x1={CHART_LEFT}
          y1={CHART_TOP}
          x2={CHART_LEFT}
          y2={CHART_TOP + CHART_H}
          stroke={palette.inkMuted}
          strokeWidth={1.2}
        />

        {/* Ceiling line */}
        <line
          x1={CHART_LEFT}
          y1={yPrice(PRICE_MAX)}
          x2={CHART_LEFT + CHART_W}
          y2={yPrice(PRICE_MAX)}
          stroke={palette.amber}
          strokeWidth={1.5}
          strokeDasharray="6 6"
        />
        <text
          x={CHART_LEFT + CHART_W + 14}
          y={yPrice(PRICE_MAX) + 6}
          fontFamily={fonts.body}
          fontSize={16}
          fill={palette.amber}
          fontWeight={600}
        >
          ceiling = R$ 1.50
        </text>

        {/* Bidders' private cost lines (horizontal dotted) */}
        {BIDDERS.map((b, i) => {
          const lineEnter = interpolate(
            frame,
            [(startSec + 1 + i * 0.4) * fps, (startSec + 1.6 + i * 0.4) * fps],
            [0, 1],
            {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
          );
          const droppedOut = clockT >= b.dropOutT;
          const lineColor = droppedOut ? palette.rule : (i === 4 ? palette.red : palette.inkSoft);
          const labelColor = droppedOut ? palette.inkMuted : (i === 4 ? palette.red : palette.ink);
          return (
            <g key={b.name} opacity={lineEnter}>
              <line
                x1={CHART_LEFT}
                y1={yPrice(b.cost)}
                x2={CHART_LEFT + CHART_W}
                y2={yPrice(b.cost)}
                stroke={lineColor}
                strokeWidth={i === 4 ? 2 : 1.2}
                strokeDasharray={i === 4 ? '0' : '4 6'}
                opacity={droppedOut ? 0.4 : 1}
              />
              <text
                x={CHART_LEFT + CHART_W + 14}
                y={yPrice(b.cost) + 6}
                fontFamily={fonts.body}
                fontSize={18}
                fill={labelColor}
                fontWeight={i === 4 ? 700 : 500}
                style={{fontVariantNumeric: 'tabular-nums'}}
              >
                {b.name} · cost {b.cost.toFixed(2)}
                {droppedOut && i !== 4 && (
                  <tspan dx={10} fill={palette.inkMuted} fontStyle="italic">
                    (out)
                  </tspan>
                )}
              </text>
            </g>
          );
        })}

        {/* Descending clock line — starts at top, falls to current price */}
        {frame >= clockStart * fps && (
          <>
            {/* Clock vertical position marker */}
            <circle
              cx={xTime(0.5)}
              cy={yPrice(currentPrice)}
              r={9}
              fill={palette.ink}
            />
            <text
              x={xTime(0.5) + 16}
              y={yPrice(currentPrice) - 16}
              fontFamily={fonts.display}
              fontSize={32}
              fontWeight={700}
              fill={palette.ink}
              style={{fontVariantNumeric: 'tabular-nums'}}
            >
              R$ {currentPrice.toFixed(2)}
            </text>
            <text
              x={xTime(0.5) + 16}
              y={yPrice(currentPrice) + 14}
              fontFamily={fonts.body}
              fontSize={14}
              fill={palette.inkMuted}
              letterSpacing="0.1em"
            >
              CLOCK PRICE
            </text>
          </>
        )}
      </svg>

      {/* Final overlay when clock stops */}
      {frame >= (clockEnd + 1) * fps && (
        <Reveal delaySec={clockEnd + 1.5 - startSec}>
          <div
            style={{
              position: 'absolute',
              bottom: 220,
              left: 0,
              right: 0,
              textAlign: 'center',
              fontFamily: fonts.display,
              fontSize: 36,
              color: palette.ink,
              fontWeight: 500,
              letterSpacing: '-0.02em',
              fontStyle: 'italic',
            }}
          >
            Firm 5 wins. Pays R$ {WINNING_PRICE.toFixed(2)}.
          </div>
        </Reveal>
      )}
    </div>
  );
};

// ============================================================================
// Phase C — Vickrey logic: winner pays runner-up's cost
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
    [(PHASE.C_END - 3) * fps, PHASE.C_END * fps],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  const opacity = enter * exit;

  return (
    <div style={{opacity, position: 'absolute', inset: 0}}>
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
          The mathematical quirk
        </div>
      </Reveal>

      <Reveal delaySec={startSec + 1.5}>
        <div
          style={{
            position: 'absolute',
            top: 250,
            left: 0,
            right: 0,
            textAlign: 'center',
            fontFamily: fonts.display,
            fontSize: 60,
            color: palette.ink,
            fontWeight: 600,
            letterSpacing: '-0.025em',
            lineHeight: 1.15,
          }}
        >
          The winning price isn't the winner's cost.
          <br />
          <span style={{color: palette.red}}>It's the runner-up's.</span>
        </div>
      </Reveal>

      {/* Three-row stat panel: winner cost / runner-up cost / paid price */}
      <Reveal delaySec={startSec + 8.0}>
        <div
          style={{
            position: 'absolute',
            top: 540,
            left: 0,
            right: 0,
            display: 'flex',
            justifyContent: 'center',
            gap: 96,
          }}
        >
          {[
            {label: "Winner's true cost", value: 'R$ 0.40', color: palette.red, sub: 'Firm 5'},
            {label: "Runner-up's cost", value: 'R$ 0.60', color: palette.blue, sub: 'Firm 4'},
            {label: 'Price paid', value: 'R$ 0.62', color: palette.ink, sub: '≈ runner-up'},
          ].map((s) => (
            <div
              key={s.label}
              style={{
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: 12,
                minWidth: 280,
              }}
            >
              <div
                style={{
                  fontFamily: fonts.body,
                  fontSize: 16,
                  color: palette.inkMuted,
                  letterSpacing: '0.16em',
                  textTransform: 'uppercase',
                  fontWeight: 500,
                }}
              >
                {s.label}
              </div>
              <div
                style={{
                  fontFamily: fonts.display,
                  fontSize: 64,
                  color: s.color,
                  fontWeight: 700,
                  letterSpacing: '-0.025em',
                  fontVariantNumeric: 'tabular-nums',
                  lineHeight: 1,
                }}
              >
                {s.value}
              </div>
              <div
                style={{
                  fontFamily: fonts.body,
                  fontSize: 18,
                  color: palette.inkSoft,
                  fontWeight: 400,
                }}
              >
                {s.sub}
              </div>
            </div>
          ))}
        </div>
      </Reveal>

      <Reveal delaySec={startSec + 28}>
        <div
          style={{
            position: 'absolute',
            bottom: 220,
            left: 0,
            right: 0,
            textAlign: 'center',
            fontFamily: fonts.display,
            fontSize: 32,
            color: palette.ink,
            fontWeight: 500,
            letterSpacing: '-0.02em',
            fontStyle: 'italic',
            lineHeight: 1.4,
            maxWidth: 1300,
            marginInline: 'auto',
          }}
        >
          You only drop your price{' '}
          <span style={{color: palette.red, fontWeight: 600}}>
            just enough
          </span>{' '}
          to force the second-most-efficient firm to give up.
        </div>
      </Reveal>
    </div>
  );
};

// ============================================================================
// Phase D — Running race analogy + policy punchline
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

  // Race animation: runners advance from left to right.
  const raceStart = startSec + 5;
  const raceEnd = startSec + 18;
  const raceT = interpolate(frame, [raceStart * fps, raceEnd * fps], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.bezier(0.45, 0, 0.55, 1),
  });
  // Runner-up sets the pace; winner stays just ahead.
  const runnerUpX = 220 + raceT * 1280;
  const winnerX = runnerUpX + 80;

  return (
    <div style={{opacity, position: 'absolute', inset: 0}}>
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
          The intuition
        </div>
      </Reveal>

      <Reveal delaySec={startSec + 1.5}>
        <div
          style={{
            position: 'absolute',
            top: 230,
            left: 0,
            right: 0,
            textAlign: 'center',
            fontFamily: fonts.display,
            fontSize: 56,
            color: palette.ink,
            fontWeight: 500,
            letterSpacing: '-0.025em',
            lineHeight: 1.2,
            maxWidth: 1500,
            marginInline: 'auto',
            fontStyle: 'italic',
          }}
        >
          You only run as fast as the runner-up forces you to.
        </div>
      </Reveal>

      {/* Track */}
      <svg width={1920} height={1080} style={{position: 'absolute', inset: 0, pointerEvents: 'none'}}>
        <line x1={120} y1={520} x2={1700} y2={520} stroke={palette.rule} strokeWidth={1} />
        <line x1={120} y1={620} x2={1700} y2={620} stroke={palette.rule} strokeWidth={1} />
        {/* Finish line */}
        <line x1={1700} y1={500} x2={1700} y2={640} stroke={palette.ink} strokeWidth={3} />
        <text
          x={1700}
          y={490}
          fontFamily={fonts.body}
          fontSize={16}
          fill={palette.inkMuted}
          letterSpacing="0.1em"
          textTransform="uppercase"
          textAnchor="middle"
        >
          finish
        </text>

        {/* Runner-up (blue) */}
        <circle cx={runnerUpX} cy={570} r={20} fill={palette.blue} opacity={0.85} />
        <text
          x={runnerUpX}
          y={680}
          fill={palette.blue}
          fontFamily={fonts.body}
          fontSize={20}
          fontWeight={600}
          textAnchor="middle"
          letterSpacing="0.04em"
        >
          runner-up
        </text>

        {/* Winner (red) */}
        <circle cx={winnerX} cy={570} r={22} fill={palette.red} opacity={0.92} />
        <text
          x={winnerX}
          y={490}
          fill={palette.red}
          fontFamily={fonts.body}
          fontSize={20}
          fontWeight={700}
          textAnchor="middle"
          letterSpacing="0.04em"
        >
          winner
        </text>
      </svg>

      {/* Policy punchline at end */}
      <Reveal delaySec={startSec + 32}>
        <div
          style={{
            position: 'absolute',
            bottom: 200,
            left: 0,
            right: 0,
            textAlign: 'center',
            fontFamily: fonts.display,
            fontSize: 38,
            color: palette.ink,
            fontWeight: 500,
            letterSpacing: '-0.02em',
            lineHeight: 1.4,
            maxWidth: 1500,
            marginInline: 'auto',
          }}
        >
          Take firms out of the room — and the runner-up gets{' '}
          <span style={{color: palette.red, fontWeight: 700}}>
            slower.
          </span>
        </div>
      </Reveal>
      <Reveal delaySec={startSec + 42}>
        <div
          style={{
            position: 'absolute',
            bottom: 130,
            left: 0,
            right: 0,
            textAlign: 'center',
            fontFamily: fonts.body,
            fontSize: 26,
            color: palette.inkSoft,
            fontWeight: 500,
            letterSpacing: '-0.005em',
          }}
        >
          The winner doesn't have to fight as hard. Prices rise.
        </div>
      </Reveal>
    </div>
  );
};

// ============================================================================
// Main scene
// ============================================================================
export const Model: React.FC = () => {
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
