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
 * Scene 05 — Drop-out identification + Pregão–Convite cross-validation.
 * 96-second scene built around a single chart that progressively
 * accumulates dropout points and (in Phase C) overlays a second auction
 * format's recovered cost CDF for the invariance check.
 *
 *   A (0-22s)   The identification challenge.
 *   B (22-62s)  Drop-out trick: build the cost CDF point-by-point.
 *   C (62-96s)  Convite cross-validation overlay.
 */

const PHASE = {
  A_END: 22,
  B_END: 62,
  C_END: 96,
} as const;

// Chart geometry (Phase B + C)
const CH_LEFT = 260;
const CH_TOP = 320;
const CH_W = 740;
const CH_H = 480;
const COST_MAX = 1.5;

const yCost = (c: number) => CH_TOP + (1 - c / COST_MAX) * CH_H;
const xTime = (t: number) => CH_LEFT + t * CH_W;

// Right-side CDF chart geometry
const CDF_LEFT = 1140;
const CDF_TOP = 320;
const CDF_W = 600;
const CDF_H = 480;

const xCDF = (c: number) => CDF_LEFT + (c / COST_MAX) * CDF_W;
const yCDF = (p: number) => CDF_TOP + (1 - p) * CDF_H;

// Bidders for the dropout demo. Sorted by cost (lowest first).
type Bidder = {name: string; cost: number; dropOutT: number};
const BIDDERS: Bidder[] = [
  {name: 'Firm A', cost: 0.38, dropOutT: 1.00}, // winner — never drops
  {name: 'Firm B', cost: 0.62, dropOutT: 0.78},
  {name: 'Firm C', cost: 0.85, dropOutT: 0.55},
  {name: 'Firm D', cost: 1.10, dropOutT: 0.30},
];

// ============================================================================
// Phase A — The identification challenge
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
      <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 40}}>
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
            The identification problem
          </div>
        </Reveal>
        <Reveal delaySec={1.2}>
          <div
            style={{
              fontFamily: fonts.display,
              fontSize: 72,
              color: palette.ink,
              fontWeight: 600,
              letterSpacing: '-0.03em',
              textAlign: 'center',
              maxWidth: 1500,
              lineHeight: 1.1,
            }}
          >
            How do we know firms' true costs
            <br />
            if{' '}
            <span style={{color: palette.red}}>
              they never tell us?
            </span>
          </div>
        </Reveal>
        <Reveal delaySec={4.5}>
          <div
            style={{
              fontFamily: fonts.body,
              fontSize: 30,
              color: palette.inkSoft,
              fontWeight: 400,
              letterSpacing: '-0.005em',
              textAlign: 'center',
              maxWidth: 1300,
              lineHeight: 1.4,
              marginTop: 12,
            }}
          >
            Bids are{' '}
            <span style={{fontStyle: 'italic'}}>strategic</span>, not honest.
            <br />
            We need to recover the underlying cost distribution.
          </div>
        </Reveal>
        <Reveal delaySec={11.0}>
          <div
            style={{
              marginTop: 36,
              fontFamily: fonts.body,
              fontSize: 22,
              color: palette.inkMuted,
              letterSpacing: '0.06em',
              textTransform: 'uppercase',
              fontWeight: 500,
              fontStyle: 'italic',
            }}
          >
            enter Haile &amp; Tamer (2003)
          </div>
        </Reveal>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// Phase B — Drop-out trick: build the cost CDF
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
    [(PHASE.B_END - 2) * fps, PHASE.B_END * fps],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  const opacity = enter * exit;

  // Clock descends through the auction over 18 seconds.
  const clockStart = startSec + 6;
  const clockEnd = startSec + 26;
  const clockT = interpolate(
    frame,
    [clockStart * fps, clockEnd * fps],
    [0, 1],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.65, 0, 0.35, 1)},
  );
  const currentPrice = COST_MAX - clockT * COST_MAX;

  return (
    <div style={{opacity, position: 'absolute', inset: 0, pointerEvents: 'none'}}>
      <Reveal delaySec={startSec + 0.5}>
        <div
          style={{
            position: 'absolute',
            top: 160,
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
          The drop-out trick
        </div>
      </Reveal>
      <Reveal delaySec={startSec + 1.2}>
        <div
          style={{
            position: 'absolute',
            top: 210,
            left: 0,
            right: 0,
            textAlign: 'center',
            fontFamily: fonts.display,
            fontSize: 38,
            color: palette.ink,
            fontWeight: 500,
            letterSpacing: '-0.02em',
            lineHeight: 1.3,
            maxWidth: 1500,
            marginInline: 'auto',
          }}
        >
          Each exit moment reveals an{' '}
          <span style={{color: palette.red, fontWeight: 600}}>
            upper bound
          </span>{' '}
          on that firm's cost.
        </div>
      </Reveal>

      <svg width={1920} height={1080} style={{position: 'absolute', inset: 0}}>
        {/* Left chart: clock descending vs bidder costs */}
        {/* Y-axis */}
        <line x1={CH_LEFT} y1={CH_TOP} x2={CH_LEFT} y2={CH_TOP + CH_H} stroke={palette.inkMuted} strokeWidth={1.2} />
        <text
          x={CH_LEFT - 100}
          y={CH_TOP + CH_H / 2}
          fill={palette.inkMuted}
          fontFamily={fonts.body}
          fontSize={16}
          fontWeight={500}
          letterSpacing="0.1em"
          transform={`rotate(-90, ${CH_LEFT - 100}, ${CH_TOP + CH_H / 2})`}
          textAnchor="middle"
        >
          PRICE (R$ / unit)
        </text>
        {[0.0, 0.5, 1.0, 1.5].map((p) => (
          <g key={p}>
            <line x1={CH_LEFT - 6} y1={yCost(p)} x2={CH_LEFT} y2={yCost(p)} stroke={palette.inkMuted} strokeWidth={1} />
            <text x={CH_LEFT - 14} y={yCost(p) + 5} fontFamily={fonts.body} fontSize={14} fill={palette.inkMuted} textAnchor="end" style={{fontVariantNumeric: 'tabular-nums'}}>
              {p.toFixed(1)}
            </text>
          </g>
        ))}

        {/* Bidder cost lines */}
        {BIDDERS.map((b, i) => {
          const lineEnter = interpolate(
            frame,
            [(startSec + 2 + i * 0.4) * fps, (startSec + 2.5 + i * 0.4) * fps],
            [0, 1],
            {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
          );
          const droppedOut = clockT >= b.dropOutT;
          const isWinner = i === 0;
          return (
            <g key={b.name} opacity={lineEnter}>
              <line
                x1={CH_LEFT}
                y1={yCost(b.cost)}
                x2={CH_LEFT + CH_W}
                y2={yCost(b.cost)}
                stroke={droppedOut ? palette.rule : (isWinner ? palette.red : palette.inkSoft)}
                strokeWidth={isWinner ? 2 : 1.2}
                strokeDasharray={isWinner ? '0' : '4 6'}
              />
              <text
                x={CH_LEFT + CH_W + 14}
                y={yCost(b.cost) + 5}
                fontFamily={fonts.body}
                fontSize={16}
                fill={droppedOut ? palette.inkMuted : (isWinner ? palette.red : palette.ink)}
                fontWeight={isWinner ? 700 : 500}
              >
                {b.name}
                {droppedOut && !isWinner && (
                  <tspan dx={8} fill={palette.red} fontStyle="italic" fontSize={14}>
                    dropped @ {b.cost.toFixed(2)}
                  </tspan>
                )}
              </text>
            </g>
          );
        })}

        {/* Descending clock dot */}
        {frame >= clockStart * fps && frame <= clockEnd * fps && (
          <>
            <circle cx={xTime(0.5)} cy={yCost(currentPrice)} r={8} fill={palette.ink} />
            <text
              x={xTime(0.5) + 14}
              y={yCost(currentPrice) - 14}
              fontFamily={fonts.display}
              fontSize={26}
              fontWeight={700}
              fill={palette.ink}
              style={{fontVariantNumeric: 'tabular-nums'}}
            >
              R$ {currentPrice.toFixed(2)}
            </text>
          </>
        )}

        {/* Right chart: F_c CDF being built point by point */}
        <line x1={CDF_LEFT} y1={CDF_TOP} x2={CDF_LEFT} y2={CDF_TOP + CDF_H} stroke={palette.inkMuted} strokeWidth={1.2} />
        <line x1={CDF_LEFT} y1={CDF_TOP + CDF_H} x2={CDF_LEFT + CDF_W} y2={CDF_TOP + CDF_H} stroke={palette.inkMuted} strokeWidth={1.2} />
        <text
          x={CDF_LEFT + CDF_W / 2}
          y={CDF_TOP - 30}
          fontFamily={fonts.body}
          fontSize={18}
          fontWeight={600}
          fill={palette.red}
          textAnchor="middle"
          letterSpacing="0.06em"
        >
          RECOVERED COST CDF · F<tspan dy={4} fontSize={12}>c</tspan>
        </text>

        {/* CDF axis labels */}
        {[0.0, 0.5, 1.0, 1.5].map((c) => (
          <text key={c} x={xCDF(c)} y={CDF_TOP + CDF_H + 26} fontFamily={fonts.body} fontSize={13} fill={palette.inkMuted} textAnchor="middle" style={{fontVariantNumeric: 'tabular-nums'}}>
            {c.toFixed(1)}
          </text>
        ))}
        <text x={CDF_LEFT + CDF_W / 2} y={CDF_TOP + CDF_H + 56} fontFamily={fonts.body} fontSize={14} fill={palette.inkMuted} textAnchor="middle" letterSpacing="0.1em">
          COST (R$ / unit)
        </text>
        {[0, 0.25, 0.5, 0.75, 1].map((p) => (
          <text key={p} x={CDF_LEFT - 12} y={yCDF(p) + 4} fontFamily={fonts.body} fontSize={13} fill={palette.inkMuted} textAnchor="end" style={{fontVariantNumeric: 'tabular-nums'}}>
            {p.toFixed(2)}
          </text>
        ))}

        {/* CDF dots accumulate as bidders drop out */}
        {BIDDERS.slice(1).map((b, i) => {
          const droppedOut = clockT >= b.dropOutT;
          if (!droppedOut) return null;
          const dotAppear = interpolate(
            frame,
            [(clockStart + (clockEnd - clockStart) * b.dropOutT) * fps,
             (clockStart + (clockEnd - clockStart) * b.dropOutT + 0.3) * fps],
            [0, 1],
            {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
          );
          // Bidders are listed so that index 0 is winner; for CDF y-axis we use rank.
          // Sort by ascending cost: A=0.38, B=0.62, C=0.85, D=1.10
          // Rank for B/C/D among non-winners: B is 1st-out-from-bottom dropped, C is 2nd, etc.
          // Empirical CDF assignment: P_i = (rank+1) / (n+1) for i = 1..n
          // Here we just show the dropout cost at its rank position.
          // For visual: Firm B at rank 2, Firm C at rank 3, Firm D at rank 4 (out of 4 firms).
          const ranks: Record<string, number> = {'Firm B': 2, 'Firm C': 3, 'Firm D': 4};
          const rank = ranks[b.name] ?? 1;
          const p = rank / 5; // (rank) / (n+1)
          return (
            <g key={b.name} opacity={dotAppear}>
              <circle cx={xCDF(b.cost)} cy={yCDF(p)} r={8} fill={palette.red} />
              <text
                x={xCDF(b.cost)}
                y={yCDF(p) - 14}
                fontFamily={fonts.body}
                fontSize={12}
                fill={palette.red}
                textAnchor="middle"
                fontWeight={600}
              >
                {b.name}
              </text>
            </g>
          );
        })}
      </svg>

      {/* Footer narrative */}
      {frame >= (clockEnd + 1) * fps && (
        <Reveal delaySec={clockEnd + 1.5 - startSec}>
          <div
            style={{
              position: 'absolute',
              bottom: 200,
              left: 0,
              right: 0,
              textAlign: 'center',
              fontFamily: fonts.display,
              fontSize: 30,
              color: palette.ink,
              fontWeight: 500,
              letterSpacing: '-0.02em',
              fontStyle: 'italic',
            }}
          >
            Three exits → three points on the cost distribution.
          </div>
        </Reveal>
      )}
    </div>
  );
};

// ============================================================================
// Phase C — Convite cross-validation
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
    [(PHASE.C_END - 2) * fps, PHASE.C_END * fps],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  const opacity = enter * exit;

  // CDF curve geometry (centred chart)
  const CX = 480;
  const CY = 300;
  const CW = 960;
  const CH = 480;
  const xC = (c: number) => CX + (c / COST_MAX) * CW;
  const yC = (p: number) => CY + (1 - p) * CH;

  // Curve sample points: smooth Beta-like CDF
  const cdfPregao = (c: number) => {
    const x = Math.max(0, Math.min(1, c / COST_MAX));
    return 1 - Math.pow(1 - x, 2.4);
  };
  // Convite is intentionally close — within 2pp at median.
  const cdfConvite = (c: number) => {
    const x = Math.max(0, Math.min(1, c / COST_MAX));
    return 1 - Math.pow(1 - x, 2.55);
  };

  const buildPath = (fn: (c: number) => number) => {
    const pts: string[] = [];
    for (let i = 0; i <= 60; i++) {
      const c = (i / 60) * COST_MAX;
      const px = xC(c);
      const py = yC(fn(c));
      pts.push(`${i === 0 ? 'M' : 'L'} ${px} ${py}`);
    }
    return pts.join(' ');
  };

  // Curves draw progressively
  const curveT = interpolate(
    frame,
    [(startSec + 4) * fps, (startSec + 10) * fps],
    [0, 1],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.16, 1, 0.3, 1)},
  );

  return (
    <div style={{opacity, position: 'absolute', inset: 0, pointerEvents: 'none'}}>
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
          The validation
        </div>
      </Reveal>
      <Reveal delaySec={startSec + 1.2}>
        <div
          style={{
            position: 'absolute',
            top: 190,
            left: 0,
            right: 0,
            textAlign: 'center',
            fontFamily: fonts.display,
            fontSize: 40,
            color: palette.ink,
            fontWeight: 500,
            letterSpacing: '-0.02em',
            lineHeight: 1.25,
          }}
        >
          A second auction format must recover the{' '}
          <span style={{color: palette.red, fontWeight: 600}}>
            same
          </span>{' '}
          cost distribution.
        </div>
      </Reveal>

      <svg width={1920} height={1080} style={{position: 'absolute', inset: 0}}>
        {/* Axes */}
        <line x1={CX} y1={CY} x2={CX} y2={CY + CH} stroke={palette.inkMuted} strokeWidth={1.2} />
        <line x1={CX} y1={CY + CH} x2={CX + CW} y2={CY + CH} stroke={palette.inkMuted} strokeWidth={1.2} />
        {[0.0, 0.5, 1.0, 1.5].map((c) => (
          <g key={c}>
            <line x1={xC(c)} y1={CY + CH} x2={xC(c)} y2={CY + CH + 6} stroke={palette.inkMuted} strokeWidth={1} />
            <text x={xC(c)} y={CY + CH + 24} fontFamily={fonts.body} fontSize={14} fill={palette.inkMuted} textAnchor="middle" style={{fontVariantNumeric: 'tabular-nums'}}>
              {c.toFixed(1)}
            </text>
          </g>
        ))}
        <text x={CX + CW / 2} y={CY + CH + 56} fontFamily={fonts.body} fontSize={15} fill={palette.inkMuted} textAnchor="middle" letterSpacing="0.1em">
          COST (R$ / unit)
        </text>
        {[0, 0.25, 0.5, 0.75, 1].map((p) => (
          <g key={p}>
            <line x1={CX - 6} y1={yC(p)} x2={CX} y2={yC(p)} stroke={palette.inkMuted} strokeWidth={1} />
            <text x={CX - 14} y={yC(p) + 5} fontFamily={fonts.body} fontSize={14} fill={palette.inkMuted} textAnchor="end" style={{fontVariantNumeric: 'tabular-nums'}}>
              {p.toFixed(2)}
            </text>
          </g>
        ))}
        <text
          x={CX - 80}
          y={CY + CH / 2}
          fontFamily={fonts.body}
          fontSize={15}
          fill={palette.inkMuted}
          letterSpacing="0.1em"
          transform={`rotate(-90, ${CX - 80}, ${CY + CH / 2})`}
          textAnchor="middle"
        >
          F<tspan dy={4} fontSize={11}>c</tspan>
        </text>

        {/* Pregão curve (red) — clipped to curveT */}
        <defs>
          <clipPath id="curveClip">
            <rect x={CX} y={CY - 10} width={CW * curveT} height={CH + 20} />
          </clipPath>
        </defs>
        <path d={buildPath(cdfPregao)} stroke={palette.red} strokeWidth={3} fill="none" clipPath="url(#curveClip)" />
        <path d={buildPath(cdfConvite)} stroke={palette.blue} strokeWidth={3} fill="none" strokeDasharray="6 6" clipPath="url(#curveClip)" />

        {/* Median annotation: at p=0.5, find the cost where each curve hits 0.5 */}
        {curveT >= 0.99 && (
          <g opacity={interpolate(frame, [(startSec + 12) * fps, (startSec + 13) * fps], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'})}>
            <line x1={CX} y1={yC(0.5)} x2={CX + CW} y2={yC(0.5)} stroke={palette.inkMuted} strokeWidth={0.8} strokeDasharray="3 5" />
            <text x={CX + CW + 14} y={yC(0.5) + 5} fontFamily={fonts.body} fontSize={14} fill={palette.inkMuted} fontWeight={500}>
              median
            </text>
          </g>
        )}
      </svg>

      {/* Right legend + invariance callout */}
      <div
        style={{
          position: 'absolute',
          left: 1500,
          top: 360,
          display: 'flex',
          flexDirection: 'column',
          gap: 28,
          maxWidth: 380,
          opacity: interpolate(frame, [(startSec + 10) * fps, (startSec + 11.5) * fps], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}),
        }}
      >
        <div style={{display: 'flex', flexDirection: 'column', gap: 14}}>
          <div style={{display: 'flex', alignItems: 'center', gap: 14}}>
            <div style={{width: 36, height: 3, backgroundColor: palette.red}} />
            <div style={{fontFamily: fonts.body, fontSize: 22, color: palette.ink, fontWeight: 600}}>
              Pregão · drop-out
            </div>
          </div>
          <div style={{display: 'flex', alignItems: 'center', gap: 14}}>
            <div style={{width: 36, height: 3, backgroundColor: palette.blue, borderTop: 'none'}} />
            <div style={{fontFamily: fonts.body, fontSize: 22, color: palette.ink, fontWeight: 600}}>
              Convite · sealed bid
            </div>
          </div>
        </div>

        <Reveal delaySec={startSec + 14}>
          <div style={{
            backgroundColor: palette.surface,
            border: `1px solid ${palette.rule}`,
            borderRadius: 10,
            padding: '20px 24px',
          }}>
            <div style={{
              fontFamily: fonts.body,
              fontSize: 14,
              color: palette.inkMuted,
              letterSpacing: '0.16em',
              textTransform: 'uppercase',
              fontWeight: 600,
              marginBottom: 8,
            }}>
              Match at median
            </div>
            <div style={{
              fontFamily: fonts.display,
              fontSize: 44,
              color: palette.red,
              fontWeight: 700,
              letterSpacing: '-0.025em',
              fontVariantNumeric: 'tabular-nums',
              lineHeight: 1,
              marginBottom: 6,
            }}>
              &lt; 2 pp
            </div>
            <div style={{
              fontFamily: fonts.body,
              fontSize: 16,
              color: palette.inkSoft,
              fontWeight: 400,
              letterSpacing: '-0.005em',
            }}>
              Two formats. Same primitive.
            </div>
          </div>
        </Reveal>
      </div>

      {/* Bottom punchline */}
      <Reveal delaySec={startSec + 22}>
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
          A strong invariance check. The math holds in the real world.
        </div>
      </Reveal>
    </div>
  );
};

// ============================================================================
// Main scene
// ============================================================================
export const Dropout: React.FC = () => {
  return (
    <Frame>
      <Chrome />
      <PhaseA />
      <PhaseB />
      <PhaseC />
    </Frame>
  );
};
