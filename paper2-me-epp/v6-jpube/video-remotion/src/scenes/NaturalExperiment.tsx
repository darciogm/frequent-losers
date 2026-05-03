import React from 'react';
import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  interpolate,
  Easing,
  Sequence,
} from 'remotion';
import {Frame} from '../components/Frame';
import {Chrome} from '../components/Chrome';
import {Reveal} from '../components/Reveal';
import {palette, fonts, sizes} from '../lib/theme';

/**
 * Scene 02 — March 2018 reinterpretation as a natural experiment.
 *
 * 196-second scene built around a horizontal timeline from 2014 to 2019.
 * Four visual movements (Phase A → B → C → D) layer onto the same
 * timeline rather than cutting away — each phase adds an annotation,
 * reframes the existing marks, or zooms in/out to reveal more context.
 *
 * Design principles applied:
 *  • Timeline anchored to a 12-column editorial grid (left margin 240,
 *    right margin 240, centered).
 *  • Group blocks use a 12-wide grid simulating the 77 product groups.
 *  • Color flips driven by phase-relative opacity ramps so transitions
 *    cross-fade rather than cut.
 */

const PHASE = {
  A_END: 26,   // 2014 federal SME law
  B_END: 76,   // Group 65 exception
  C_END: 130,  // March 2018 reinterpretation
  D_END: 196,  // Quasi-experiment recap
} as const;

// ---- Timeline geometry ---------------------------------------------------
const TL_LEFT = 240;
const TL_RIGHT = 1680;          // 1920 - 240
const TL_Y = 540;               // visual center
const TL_WIDTH = TL_RIGHT - TL_LEFT;
const YEARS = [2014, 2015, 2016, 2017, 2018, 2019];
// Cutoff sits at March 2018 → 4 + 2/12 of the 5-year span from 2014 to 2019.
const CUTOFF_FRAC = (2018 + 2 / 12 - 2014) / 5;
const CUTOFF_X = TL_LEFT + CUTOFF_FRAC * TL_WIDTH;

const yearX = (y: number) => TL_LEFT + ((y - 2014) / 5) * TL_WIDTH;

// ---- Group blocks geometry -----------------------------------------------
// 77 product groups represented as a 11x7 grid below the timeline.
const N_COLS = 11;
const N_ROWS = 7;
const N_BLOCKS = N_COLS * N_ROWS;          // 77
const GROUP_65_INDEX = 32;                 // arbitrary cell to highlight
const BLOCK_W = 80;
const BLOCK_H = 22;
const BLOCK_GAP = 8;
const GRID_WIDTH = N_COLS * BLOCK_W + (N_COLS - 1) * BLOCK_GAP;
const GRID_LEFT = (1920 - GRID_WIDTH) / 2;
const GRID_TOP = 720;

const BlockGrid: React.FC<{
  /** 0 = before 2014; 1 = G65 still open; 2 = G65 flipped to SME-only */
  phase: 0 | 1 | 2;
  /** smooth interp between phases (0..1 from previous phase to current) */
  blend: number;
}> = ({phase, blend}) => {
  return (
    <g>
      {Array.from({length: N_BLOCKS}).map((_, i) => {
        const col = i % N_COLS;
        const row = Math.floor(i / N_COLS);
        const x = GRID_LEFT + col * (BLOCK_W + BLOCK_GAP);
        const y = GRID_TOP + row * (BLOCK_H + BLOCK_GAP);
        const isG65 = i === GROUP_65_INDEX;

        let fill = palette.rule;
        if (phase === 0) fill = palette.rule;
        if (phase === 1) {
          // All red except G65 which is blue
          fill = isG65 ? palette.blue : palette.red;
        }
        if (phase === 2) {
          // All red, G65 flips red too
          fill = palette.red;
        }

        // Cross-fade colors via two stacked rects when blending.
        const opacity = isG65 ? 0.92 : 0.55;
        return (
          <rect
            key={i}
            x={x}
            y={y}
            width={BLOCK_W}
            height={BLOCK_H}
            fill={fill}
            opacity={opacity}
            rx={2}
          />
        );
      })}
    </g>
  );
};

// ---- Timeline component --------------------------------------------------
const Timeline: React.FC<{frame: number; fps: number}> = ({frame, fps}) => {
  const lineProg = interpolate(frame, [0, fps * 1.4], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });

  return (
    <svg
      width={1920}
      height={1080}
      style={{position: 'absolute', inset: 0, pointerEvents: 'none'}}
    >
      {/* Main horizontal line */}
      <line
        x1={TL_LEFT}
        y1={TL_Y}
        x2={TL_LEFT + lineProg * TL_WIDTH}
        y2={TL_Y}
        stroke={palette.inkSoft}
        strokeWidth={1.5}
      />

      {/* Year ticks */}
      {YEARS.map((y, i) => {
        const x = yearX(y);
        const tickAppear = interpolate(
          frame,
          [fps * (0.6 + i * 0.12), fps * (1.0 + i * 0.12)],
          [0, 1],
          {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
        );
        return (
          <g key={y} opacity={tickAppear}>
            <line
              x1={x}
              y1={TL_Y - 8}
              x2={x}
              y2={TL_Y + 8}
              stroke={palette.inkSoft}
              strokeWidth={1.2}
            />
            <text
              x={x}
              y={TL_Y + 36}
              textAnchor="middle"
              fontFamily={fonts.body}
              fontSize={20}
              fill={palette.inkMuted}
              fontWeight={500}
              style={{fontVariantNumeric: 'tabular-nums'}}
            >
              {y}
            </text>
          </g>
        );
      })}
    </svg>
  );
};

// ---- The four phases as separate overlay components ---------------------

const PhaseA: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const exit = interpolate(frame, [(PHASE.A_END - 2) * fps, PHASE.A_END * fps], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  return (
    <div style={{opacity: exit}}>
      <Reveal delaySec={1.5}>
        <div
          style={{
            position: 'absolute',
            top: 220,
            left: 240,
            width: 1440,
            textAlign: 'center',
            fontFamily: fonts.display,
            fontSize: 72,
            color: palette.ink,
            fontWeight: 600,
            letterSpacing: '-0.025em',
            lineHeight: 1.1,
          }}
        >
          Brazil's federal SME law
        </div>
      </Reveal>
      <Reveal delaySec={3.5}>
        <div
          style={{
            position: 'absolute',
            top: 340,
            left: 240,
            width: 1440,
            textAlign: 'center',
            fontFamily: fonts.body,
            fontSize: 32,
            color: palette.inkSoft,
            fontWeight: 400,
            letterSpacing: '-0.005em',
          }}
        >
          Any government purchase under{' '}
          <span style={{color: palette.red, fontWeight: 600}}>R$ 80,000</span>
          {' '}must be reserved exclusively for SMEs.
        </div>
      </Reveal>

      {/* Pulse on 2014 marker */}
      <Reveal delaySec={5.5}>
        <div
          style={{
            position: 'absolute',
            left: yearX(2014) - 80,
            top: TL_Y - 110,
            width: 160,
            textAlign: 'center',
            fontFamily: fonts.body,
            fontSize: 18,
            color: palette.red,
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            fontWeight: 600,
          }}
        >
          law passed
        </div>
      </Reveal>
    </div>
  );
};

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
    [(PHASE.B_END - 2) * fps, PHASE.B_END * fps],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  const opacity = enter * exit;
  return (
    <div style={{opacity}}>
      <Reveal delaySec={startSec + 1.0}>
        <div
          style={{
            position: 'absolute',
            top: 200,
            left: 240,
            width: 1440,
            textAlign: 'center',
            fontFamily: fonts.body,
            fontSize: 22,
            color: palette.blue,
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            fontWeight: 600,
          }}
        >
          One exception
        </div>
      </Reveal>
      <Reveal delaySec={startSec + 2.0}>
        <div
          style={{
            position: 'absolute',
            top: 250,
            left: 240,
            width: 1440,
            textAlign: 'center',
            fontFamily: fonts.display,
            fontSize: 64,
            color: palette.ink,
            fontWeight: 600,
            letterSpacing: '-0.025em',
            lineHeight: 1.1,
          }}
        >
          Group 65: medical supplies
        </div>
      </Reveal>
      <Reveal delaySec={startSec + 4.0}>
        <div
          style={{
            position: 'absolute',
            top: 360,
            left: 240,
            width: 1440,
            textAlign: 'center',
            fontFamily: fonts.body,
            fontSize: 28,
            color: palette.inkSoft,
            fontWeight: 400,
            letterSpacing: '-0.005em',
            lineHeight: 1.4,
          }}
        >
          Exempted by the state audit court — deemed{' '}
          <span style={{color: palette.blue, fontWeight: 600}}>strategic.</span>
          <br />
          For four years, hospital supplies stayed open to all bidders.
        </div>
      </Reveal>

      {/* Bracket on timeline showing the exempt window 2014→Mar 2018 */}
      <svg
        width={1920}
        height={1080}
        style={{position: 'absolute', inset: 0, pointerEvents: 'none'}}
      >
        <line
          x1={yearX(2014)}
          y1={TL_Y - 40}
          x2={CUTOFF_X}
          y2={TL_Y - 40}
          stroke={palette.blue}
          strokeWidth={3}
        />
        <line
          x1={yearX(2014)}
          y1={TL_Y - 50}
          x2={yearX(2014)}
          y2={TL_Y - 30}
          stroke={palette.blue}
          strokeWidth={2}
        />
        <line
          x1={CUTOFF_X}
          y1={TL_Y - 50}
          x2={CUTOFF_X}
          y2={TL_Y - 30}
          stroke={palette.blue}
          strokeWidth={2}
        />
        <text
          x={(yearX(2014) + CUTOFF_X) / 2}
          y={TL_Y - 60}
          textAnchor="middle"
          fontFamily={fonts.body}
          fontSize={18}
          fill={palette.blue}
          fontWeight={600}
          letterSpacing="0.06em"
        >
          G65 OPEN — 2014 to Feb 2018
        </text>
      </svg>
    </div>
  );
};

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
    [(PHASE.C_END - 2) * fps, PHASE.C_END * fps],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  const opacity = enter * exit;

  // Pulse on the cutoff
  const pulse = 0.5 + 0.5 * Math.sin((frame / fps) * 2);

  return (
    <div style={{opacity}}>
      <Reveal delaySec={startSec + 1.0}>
        <div
          style={{
            position: 'absolute',
            top: 200,
            left: 240,
            width: 1440,
            textAlign: 'center',
            fontFamily: fonts.body,
            fontSize: 22,
            color: palette.red,
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            fontWeight: 600,
          }}
        >
          March 2018
        </div>
      </Reveal>
      <Reveal delaySec={startSec + 2.0}>
        <div
          style={{
            position: 'absolute',
            top: 250,
            left: 240,
            width: 1440,
            textAlign: 'center',
            fontFamily: fonts.display,
            fontSize: 60,
            color: palette.ink,
            fontWeight: 600,
            letterSpacing: '-0.025em',
            lineHeight: 1.1,
          }}
        >
          The exception is reversed.
        </div>
      </Reveal>
      <Reveal delaySec={startSec + 4.0}>
        <div
          style={{
            position: 'absolute',
            top: 350,
            left: 240,
            width: 1440,
            textAlign: 'center',
            fontFamily: fonts.body,
            fontSize: 26,
            color: palette.inkSoft,
            fontWeight: 400,
            letterSpacing: '-0.005em',
            lineHeight: 1.45,
          }}
        >
          No market crisis. No price spike. No supplier complaints.
          <br />
          A legalistic reinterpretation —{' '}
          <span style={{fontStyle: 'italic'}}>isonomy</span> — by the state attorney general.
        </div>
      </Reveal>

      {/* Big red marker pulsing at Mar 2018 cutoff */}
      <svg
        width={1920}
        height={1080}
        style={{position: 'absolute', inset: 0, pointerEvents: 'none'}}
      >
        <line
          x1={CUTOFF_X}
          y1={TL_Y - 70}
          x2={CUTOFF_X}
          y2={TL_Y + 70}
          stroke={palette.red}
          strokeWidth={4}
          opacity={0.5 + 0.5 * pulse}
        />
        <circle
          cx={CUTOFF_X}
          cy={TL_Y}
          r={10}
          fill={palette.red}
          opacity={0.7 + 0.3 * pulse}
        />
        <text
          x={CUTOFF_X}
          y={TL_Y - 90}
          textAnchor="middle"
          fontFamily={fonts.body}
          fontSize={20}
          fill={palette.red}
          fontWeight={700}
          letterSpacing="0.06em"
        >
          MAR 2018
        </text>
      </svg>
    </div>
  );
};

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
    <div style={{opacity}}>
      <Reveal delaySec={startSec + 1.0}>
        <div
          style={{
            position: 'absolute',
            top: 200,
            left: 240,
            width: 1440,
            textAlign: 'center',
            fontFamily: fonts.body,
            fontSize: 22,
            color: palette.red,
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            fontWeight: 600,
          }}
        >
          A pristine quasi-experiment
        </div>
      </Reveal>

      <Reveal delaySec={startSec + 2.5}>
        <div
          style={{
            position: 'absolute',
            top: 280,
            left: 0,
            right: 0,
            display: 'flex',
            justifyContent: 'center',
            gap: 120,
          }}
        >
          {/* Switching group panel */}
          <div
            style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: 12,
            }}
          >
            <div
              style={{
                fontFamily: fonts.display,
                fontSize: 96,
                color: palette.red,
                fontWeight: 700,
                letterSpacing: '-0.03em',
                fontVariantNumeric: 'tabular-nums',
                lineHeight: 1,
              }}
            >
              1
            </div>
            <div
              style={{
                fontFamily: fonts.body,
                fontSize: 24,
                color: palette.ink,
                fontWeight: 500,
                letterSpacing: '-0.005em',
              }}
            >
              switching group
            </div>
            <div
              style={{
                fontFamily: fonts.body,
                fontSize: 18,
                color: palette.inkMuted,
              }}
            >
              Group 65 — medical supplies
            </div>
          </div>

          {/* Plus sign */}
          <div
            style={{
              fontFamily: fonts.display,
              fontSize: 64,
              color: palette.inkMuted,
              fontWeight: 400,
              alignSelf: 'center',
              lineHeight: 1,
            }}
          >
            +
          </div>

          {/* Control groups panel */}
          <div
            style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: 12,
            }}
          >
            <div
              style={{
                fontFamily: fonts.display,
                fontSize: 96,
                color: palette.inkSoft,
                fontWeight: 700,
                letterSpacing: '-0.03em',
                fontVariantNumeric: 'tabular-nums',
                lineHeight: 1,
              }}
            >
              76
            </div>
            <div
              style={{
                fontFamily: fonts.body,
                fontSize: 24,
                color: palette.ink,
                fontWeight: 500,
                letterSpacing: '-0.005em',
              }}
            >
              always-treated controls
            </div>
            <div
              style={{
                fontFamily: fonts.body,
                fontSize: 18,
                color: palette.inkMuted,
              }}
            >
              SME-only since 2014
            </div>
          </div>
        </div>
      </Reveal>

      <Reveal delaySec={startSec + 8.0}>
        <div
          style={{
            position: 'absolute',
            bottom: 200,
            left: 240,
            width: 1440,
            textAlign: 'center',
            fontFamily: fonts.display,
            fontSize: 36,
            color: palette.ink,
            fontWeight: 500,
            letterSpacing: '-0.02em',
            lineHeight: 1.3,
            fontStyle: 'italic',
          }}
        >
          A clean before-and-after picture,
          <br />
          handed to economists by a bureaucratic accident.
        </div>
      </Reveal>
    </div>
  );
};

// ---- Main scene ---------------------------------------------------------
export const NaturalExperiment: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  return (
    <Frame>
      <Chrome />

      {/* Persistent timeline (renders progressively over Phase A, then stays) */}
      <Timeline frame={frame} fps={fps} />

      {/* Phase overlays — they fade in/out around the timeline */}
      <PhaseA />
      <PhaseB />
      <PhaseC />
      <PhaseD />
    </Frame>
  );
};
