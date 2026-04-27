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
 * Scene 07 — Welfare and the marginal cost of public funds (MCPF).
 * 81-second scene structured in three phases:
 *
 *   A (0-26s)   MCPF definition + country anchor strip (US 0.20, OECD 0.30,
 *               Brazil 0.40).
 *   B (26-58s)  Welfare-loss curve as a function of λ, two series:
 *               pharma vs non-pharma.
 *   C (58-81s)  Punchline — at λ = 0.40 (Brazil), pharma welfare loss
 *               hits ~50% of the baseline price.
 */

const PHASE = {
  A_END: 26,
  B_END: 58,
  C_END: 81,
} as const;

// Welfare-loss data calibrated against tab_v3_welfare.tex (loss_pct_S1).
// λ → loss% of baseline S1 price.
const LAMBDAS = [0.15, 0.20, 0.30, 0.40, 0.45];
const PHARMA_LOSS = [26.3, 30.0, 33.7, 46.4, 50.3];
const NONPHARMA_LOSS = [12.4, 14.2, 18.0, 24.6, 27.1];

// ============================================================================
// Phase A — MCPF definition + country anchors
// ============================================================================
const PhaseA: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const exit = interpolate(frame, [(PHASE.A_END - 2) * fps, PHASE.A_END * fps], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const ANCHORS = [
    {country: 'US',     lambda: 0.20, color: palette.blue,    detail: 'low MCPF'},
    {country: 'OECD',   lambda: 0.30, color: palette.inkSoft, detail: 'median'},
    {country: 'Brazil', lambda: 0.40, color: palette.red,     detail: 'complex tax system'},
  ];

  // Slider geometry
  const SCALE_LEFT = 380;
  const SCALE_RIGHT = 1540;
  const SCALE_Y = 720;
  const lambdaToX = (l: number) => SCALE_LEFT + ((l - 0.10) / (0.50 - 0.10)) * (SCALE_RIGHT - SCALE_LEFT);

  return (
    <AbsoluteFill style={{opacity: exit, pointerEvents: 'none'}}>
      <div style={{
        position: 'absolute',
        top: 200, left: 0, right: 0,
        textAlign: 'center',
      }}>
        <Reveal delaySec={0.4}>
          <div style={{
            fontFamily: fonts.body,
            fontSize: 22,
            color: palette.red,
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            fontWeight: 600,
            marginBottom: 28,
          }}>
            From R$ to welfare
          </div>
        </Reveal>
        <Reveal delaySec={1.2}>
          <div style={{
            fontFamily: fonts.display,
            fontSize: 60,
            color: palette.ink,
            fontWeight: 600,
            letterSpacing: '-0.025em',
            lineHeight: 1.15,
          }}>
            Marginal cost of public funds{' — '}
            <span style={{color: palette.red}}>λ</span>
          </div>
        </Reveal>
        <Reveal delaySec={3.8}>
          <div style={{
            fontFamily: fonts.body,
            fontSize: 30,
            color: palette.inkSoft,
            fontWeight: 400,
            letterSpacing: '-0.005em',
            marginTop: 24,
            maxWidth: 1300,
            marginInline: 'auto',
            lineHeight: 1.45,
          }}>
            Each extra real of public spending costs society{' '}
            <span style={{fontFamily: fonts.display, fontWeight: 700, color: palette.red}}>
              R$ (1 + λ).
            </span>
            <br />
            Taxes distort. λ measures the collateral damage.
          </div>
        </Reveal>
      </div>

      {/* Country anchor scale */}
      <svg width={1920} height={1080} style={{position: 'absolute', inset: 0}}>
        {/* Scale line */}
        <line
          x1={SCALE_LEFT} y1={SCALE_Y} x2={SCALE_RIGHT} y2={SCALE_Y}
          stroke={palette.inkMuted} strokeWidth={2}
          opacity={interpolate(frame, [10 * fps, 11.5 * fps], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'})}
        />
        {/* Tick at 0.10, 0.20, ..., 0.50 */}
        {[0.10, 0.20, 0.30, 0.40, 0.50].map((l) => (
          <g key={l} opacity={interpolate(frame, [(10.5 + (l - 0.10) * 8) * fps, (11.5 + (l - 0.10) * 8) * fps], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'})}>
            <line x1={lambdaToX(l)} y1={SCALE_Y - 8} x2={lambdaToX(l)} y2={SCALE_Y + 8} stroke={palette.inkMuted} strokeWidth={1.2} />
            <text
              x={lambdaToX(l)}
              y={SCALE_Y + 32}
              textAnchor="middle"
              fontFamily={fonts.body}
              fontSize={16}
              fill={palette.inkMuted}
              style={{fontVariantNumeric: 'tabular-nums'}}
            >
              {l.toFixed(2)}
            </text>
          </g>
        ))}
        <text
          x={SCALE_RIGHT + 28}
          y={SCALE_Y + 6}
          fontFamily={fonts.body}
          fontSize={20}
          fontWeight={600}
          fill={palette.inkMuted}
          letterSpacing="0.04em"
        >
          λ
        </text>

        {/* Country anchors. Pin lives in its own clean column above the
            scale; the qualitative detail ("low MCPF" / "median" / "complex
            tax system") sits BELOW the scale and tick numbers so the pin
            doesn't bisect it. */}
        {ANCHORS.map((a, i) => {
          const op = interpolate(frame, [(13 + i * 1.5) * fps, (14 + i * 1.5) * fps], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
          const x = lambdaToX(a.lambda);
          return (
            <g key={a.country} opacity={op}>
              {/* Pin from circle down to scale */}
              <line x1={x} y1={SCALE_Y - 8} x2={x} y2={SCALE_Y - 90} stroke={a.color} strokeWidth={2} />
              <circle cx={x} cy={SCALE_Y - 90} r={9} fill={a.color} />
              {/* Country name + λ value above the circle */}
              <text
                x={x}
                y={SCALE_Y - 150}
                textAnchor="middle"
                fontFamily={fonts.body}
                fontSize={20}
                fontWeight={700}
                fill={a.color}
                letterSpacing="0.08em"
                style={{textTransform: 'uppercase'}}
              >
                {a.country}
              </text>
              <text
                x={x}
                y={SCALE_Y - 118}
                textAnchor="middle"
                fontFamily={fonts.body}
                fontSize={17}
                fontWeight={600}
                fill={a.color}
                style={{fontVariantNumeric: 'tabular-nums'}}
              >
                λ = {a.lambda.toFixed(2)}
              </text>
              {/* Detail caption BELOW the scale */}
              <text
                x={x}
                y={SCALE_Y + 64}
                textAnchor="middle"
                fontFamily={fonts.body}
                fontSize={15}
                fill={a.color}
                fontStyle="italic"
                opacity={0.85}
              >
                {a.detail}
              </text>
            </g>
          );
        })}
      </svg>
    </AbsoluteFill>
  );
};

// ============================================================================
// Phase B — Welfare loss curve (pharma vs non-pharma)
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
    [(PHASE.B_END - 2) * fps, PHASE.B_END * fps],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  const opacity = enter * exit;

  // Chart axes
  const CX = 320;
  const CY = 320;
  const CW = 1280;
  const CH = 480;
  const xLam = (l: number) => CX + ((l - 0.10) / (0.50 - 0.10)) * CW;
  const yLoss = (p: number) => CY + (1 - p / 60) * CH; // 0..60% scale

  // Curve draw progression
  const curveT = interpolate(
    frame,
    [(startSec + 4) * fps, (startSec + 11) * fps],
    [0, 1],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.16, 1, 0.3, 1)},
  );

  const buildPath = (xs: number[], ys: number[]) => {
    const pts: string[] = [];
    for (let i = 0; i < xs.length; i++) {
      const px = xLam(xs[i]);
      const py = yLoss(ys[i]);
      pts.push(`${i === 0 ? 'M' : 'L'} ${px} ${py}`);
    }
    return pts.join(' ');
  };

  return (
    <div style={{opacity, position: 'absolute', inset: 0, pointerEvents: 'none'}}>
      <Reveal delaySec={startSec + 0.4}>
        <div style={{
          position: 'absolute',
          top: 160, left: 0, right: 0,
          textAlign: 'center',
          fontFamily: fonts.body,
          fontSize: 22,
          color: palette.red,
          letterSpacing: '0.18em',
          textTransform: 'uppercase',
          fontWeight: 600,
        }}>
          Welfare loss as a function of λ
        </div>
      </Reveal>
      <Reveal delaySec={startSec + 1.2}>
        <div style={{
          position: 'absolute',
          top: 210, left: 0, right: 0,
          textAlign: 'center',
          fontFamily: fonts.display,
          fontSize: 38,
          color: palette.ink,
          fontWeight: 500,
          letterSpacing: '-0.02em',
          lineHeight: 1.25,
          maxWidth: 1500,
          marginInline: 'auto',
        }}>
          The higher the tax distortion, the larger the welfare hit.
        </div>
      </Reveal>

      <svg width={1920} height={1080} style={{position: 'absolute', inset: 0}}>
        {/* Grid lines */}
        {[0, 10, 20, 30, 40, 50, 60].map((p) => (
          <g key={p}>
            <line x1={CX} y1={yLoss(p)} x2={CX + CW} y2={yLoss(p)} stroke={palette.rule} strokeWidth={0.8} />
            <text x={CX - 16} y={yLoss(p) + 5} textAnchor="end" fontFamily={fonts.body} fontSize={14} fill={palette.inkMuted} style={{fontVariantNumeric: 'tabular-nums'}}>
              {p}%
            </text>
          </g>
        ))}
        {/* Y axis */}
        <line x1={CX} y1={CY} x2={CX} y2={CY + CH} stroke={palette.inkMuted} strokeWidth={1.2} />
        <text
          x={CX - 90}
          y={CY + CH / 2}
          fontFamily={fonts.body}
          fontSize={15}
          fill={palette.inkMuted}
          letterSpacing="0.1em"
          transform={`rotate(-90, ${CX - 90}, ${CY + CH / 2})`}
          textAnchor="middle"
        >
          WELFARE LOSS · % OF BASELINE PRICE
        </text>

        {/* X axis */}
        <line x1={CX} y1={CY + CH} x2={CX + CW} y2={CY + CH} stroke={palette.inkMuted} strokeWidth={1.2} />
        {LAMBDAS.map((l) => (
          <g key={l}>
            <line x1={xLam(l)} y1={CY + CH} x2={xLam(l)} y2={CY + CH + 8} stroke={palette.inkMuted} strokeWidth={1} />
            <text x={xLam(l)} y={CY + CH + 28} textAnchor="middle" fontFamily={fonts.body} fontSize={14} fill={palette.inkMuted} style={{fontVariantNumeric: 'tabular-nums'}}>
              {l.toFixed(2)}
            </text>
          </g>
        ))}
        <text x={CX + CW / 2} y={CY + CH + 60} textAnchor="middle" fontFamily={fonts.body} fontSize={15} fill={palette.inkMuted} letterSpacing="0.1em">
          λ · MCPF
        </text>

        {/* Curve clip */}
        <defs>
          <clipPath id="curveCl2">
            <rect x={CX} y={CY - 10} width={CW * curveT} height={CH + 20} />
          </clipPath>
        </defs>

        {/* Pharma curve (red) */}
        <path
          d={buildPath(LAMBDAS, PHARMA_LOSS)}
          stroke={palette.red}
          strokeWidth={3.5}
          fill="none"
          clipPath="url(#curveCl2)"
        />
        {LAMBDAS.map((l, i) => {
          const px = xLam(l);
          const py = yLoss(PHARMA_LOSS[i]);
          const visible = curveT >= (i + 1) / LAMBDAS.length - 0.05;
          return (
            <circle key={`ph-${l}`} cx={px} cy={py} r={7} fill={palette.red} opacity={visible ? 1 : 0} />
          );
        })}

        {/* Non-pharma curve (blue) */}
        <path
          d={buildPath(LAMBDAS, NONPHARMA_LOSS)}
          stroke={palette.blue}
          strokeWidth={3.5}
          fill="none"
          clipPath="url(#curveCl2)"
          strokeDasharray="6 6"
        />
        {LAMBDAS.map((l, i) => {
          const px = xLam(l);
          const py = yLoss(NONPHARMA_LOSS[i]);
          const visible = curveT >= (i + 1) / LAMBDAS.length - 0.05;
          return (
            <circle key={`nh-${l}`} cx={px} cy={py} r={6} fill={palette.blue} opacity={visible ? 1 : 0} />
          );
        })}

        {/* Inline labels at the right end of each curve */}
        {curveT >= 0.99 && (
          <>
            <text
              x={xLam(LAMBDAS[LAMBDAS.length - 1]) + 20}
              y={yLoss(PHARMA_LOSS[PHARMA_LOSS.length - 1]) + 5}
              fontFamily={fonts.body}
              fontSize={20}
              fontWeight={700}
              fill={palette.red}
            >
              pharma
            </text>
            <text
              x={xLam(LAMBDAS[LAMBDAS.length - 1]) + 20}
              y={yLoss(NONPHARMA_LOSS[NONPHARMA_LOSS.length - 1]) + 5}
              fontFamily={fonts.body}
              fontSize={20}
              fontWeight={700}
              fill={palette.blue}
            >
              non-pharma
            </text>
          </>
        )}
      </svg>
    </div>
  );
};

// ============================================================================
// Phase C — Punchline at λ = 0.40
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

  const counter = interpolate(
    frame,
    [(startSec + 3) * fps, (startSec + 5.5) * fps],
    [0, 50],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.bezier(0.16, 1, 0.3, 1)},
  );

  return (
    <AbsoluteFill style={{opacity, alignItems: 'center', justifyContent: 'center', pointerEvents: 'none'}}>
      <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 36}}>
        <Reveal delaySec={startSec + 0.5}>
          <div style={{
            fontFamily: fonts.body,
            fontSize: 22,
            color: palette.red,
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            fontWeight: 600,
          }}>
            At Brazil's λ = 0.40
          </div>
        </Reveal>
        <Reveal delaySec={startSec + 1.2}>
          <div style={{
            fontFamily: fonts.display,
            fontSize: 44,
            color: palette.inkSoft,
            fontWeight: 500,
            letterSpacing: '-0.02em',
            textAlign: 'center',
          }}>
            The pharmaceutical SME-only rule generates
          </div>
        </Reveal>

        <div style={{display: 'flex', alignItems: 'baseline', gap: 16}}>
          <span style={{
            fontFamily: fonts.display,
            fontSize: 240,
            color: palette.red,
            fontWeight: 700,
            letterSpacing: '-0.045em',
            fontVariantNumeric: 'tabular-nums',
            lineHeight: 1,
          }}>
            {Math.round(counter)}
          </span>
          <span style={{
            fontFamily: fonts.display,
            fontSize: 120,
            color: palette.red,
            fontWeight: 600,
            letterSpacing: '-0.04em',
            lineHeight: 1,
          }}>
            %
          </span>
        </div>

        <Reveal delaySec={startSec + 6}>
          <div style={{
            fontFamily: fonts.display,
            fontSize: 38,
            color: palette.ink,
            fontWeight: 500,
            letterSpacing: '-0.02em',
            textAlign: 'center',
            maxWidth: 1500,
            lineHeight: 1.3,
            fontStyle: 'italic',
          }}>
            of welfare loss, as a fraction of the baseline price.
          </div>
        </Reveal>
        <Reveal delaySec={startSec + 12}>
          <div style={{
            marginTop: 18,
            fontFamily: fonts.body,
            fontSize: 22,
            color: palette.inkMuted,
            letterSpacing: '0.06em',
            textTransform: 'uppercase',
            fontWeight: 500,
            fontStyle: 'italic',
          }}>
            allocative DWL + tax-distortion overhead
          </div>
        </Reveal>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// Main scene
// ============================================================================
export const WelfareLambda: React.FC = () => {
  return (
    <Frame>
      <Chrome />
      <PhaseA />
      <PhaseB />
      <PhaseC />
    </Frame>
  );
};
