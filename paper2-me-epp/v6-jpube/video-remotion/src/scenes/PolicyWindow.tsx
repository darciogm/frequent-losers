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
 * Scene 08 — A 10% price preference. 51-second scene structured in
 * three phases:
 *
 *   A (0-12s)  The policy question — is there a better way?
 *   B (12-38s) Concrete scoring example: large firm vs SME bid; the SME
 *              gets a 10% scoring discount and wins the auction.
 *   C (38-51s) Punchline — large firms stay in the room as runner-up,
 *              SMEs forced to bid hard, near-zero fiscal cost.
 */

const PHASE = {
  A_END: 12,
  B_END: 38,
  C_END: 51,
} as const;

// ============================================================================
// Phase A — The question
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
      style={{opacity: exit, alignItems: 'center', justifyContent: 'center', pointerEvents: 'none'}}
    >
      <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 36}}>
        <Reveal delaySec={0.4}>
          <div style={{
            fontFamily: fonts.body,
            fontSize: 22,
            color: palette.red,
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            fontWeight: 600,
          }}>
            The policy question
          </div>
        </Reveal>
        <Reveal delaySec={1.0}>
          <div style={{
            fontFamily: fonts.display,
            fontSize: 72,
            color: palette.ink,
            fontWeight: 600,
            letterSpacing: '-0.03em',
            textAlign: 'center',
            maxWidth: 1500,
            lineHeight: 1.1,
          }}>
            Is there a better way
            <br />
            to help SMEs?
          </div>
        </Reveal>
        <Reveal delaySec={4.5}>
          <div style={{
            fontFamily: fonts.body,
            fontSize: 30,
            color: palette.inkSoft,
            fontWeight: 400,
            letterSpacing: '-0.005em',
            textAlign: 'center',
            maxWidth: 1300,
            lineHeight: 1.4,
            marginTop: 12,
          }}>
            Without paying 50% of the bill in welfare loss.
          </div>
        </Reveal>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// Phase B — Scoring example
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

  // Card layout
  const CARD_W = 460;
  const CARD_H = 460;
  const CARD_LARGE_X = 460;
  const CARD_SME_X = 1000;
  const CARD_Y = 360;

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
          A 10% price preference
        </div>
      </Reveal>
      <Reveal delaySec={startSec + 1.0}>
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
          Don't ban anyone.{' '}
          <span style={{color: palette.red, fontWeight: 600}}>
            Score
          </span>{' '}
          the SME bid 10% lower.
        </div>
      </Reveal>

      {/* Large firm card */}
      <Reveal delaySec={startSec + 4.0} tx={-30}>
        <div style={{
          position: 'absolute',
          left: CARD_LARGE_X,
          top: CARD_Y,
          width: CARD_W,
          height: CARD_H,
          backgroundColor: palette.surface,
          border: `1px solid ${palette.rule}`,
          borderRadius: 14,
          padding: '36px 32px',
          display: 'flex',
          flexDirection: 'column',
          gap: 18,
        }}>
          <div style={{
            fontFamily: fonts.body,
            fontSize: 18,
            color: palette.blue,
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            fontWeight: 700,
          }}>
            Large firm
          </div>

          <div style={{flex: 1}}>
            <Row label="Submitted bid" value="R$ 100" color={palette.ink} />
            <Hairline />
            <Row label="Scoring discount" value="—" color={palette.inkMuted} />
            <Hairline />
            <Row label="Scored bid" value="R$ 100" color={palette.ink} bold />
          </div>

          <Reveal delaySec={startSec + 18}>
            <div style={{
              fontFamily: fonts.body,
              fontSize: 22,
              color: palette.inkMuted,
              fontWeight: 600,
              letterSpacing: '0.04em',
              textTransform: 'uppercase',
              textAlign: 'center',
              padding: '12px 16px',
              backgroundColor: palette.paper,
              border: `1px solid ${palette.rule}`,
              borderRadius: 10,
            }}>
              loses
            </div>
          </Reveal>
        </div>
      </Reveal>

      {/* SME card */}
      <Reveal delaySec={startSec + 8.0} tx={30}>
        <div style={{
          position: 'absolute',
          left: CARD_SME_X,
          top: CARD_Y,
          width: CARD_W,
          height: CARD_H,
          backgroundColor: palette.surface,
          border: `2px solid ${palette.red}`,
          borderRadius: 14,
          padding: '36px 32px',
          display: 'flex',
          flexDirection: 'column',
          gap: 18,
        }}>
          <div style={{
            fontFamily: fonts.body,
            fontSize: 18,
            color: palette.red,
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            fontWeight: 700,
          }}>
            SME
          </div>

          <div style={{flex: 1}}>
            <Row label="Submitted bid" value="R$ 110" color={palette.ink} />
            <Hairline />
            <Row label="Scoring discount" value="× 0.90" color={palette.red} />
            <Hairline />
            <Row label="Scored bid" value="R$ 99" color={palette.red} bold />
          </div>

          <Reveal delaySec={startSec + 18}>
            <div style={{
              fontFamily: fonts.body,
              fontSize: 22,
              color: palette.red,
              fontWeight: 700,
              letterSpacing: '0.04em',
              textTransform: 'uppercase',
              textAlign: 'center',
              padding: '12px 16px',
              backgroundColor: palette.red,
              color: palette.paper,
              border: `1px solid ${palette.red}`,
              borderRadius: 10,
            }}>
              wins
            </div>
          </Reveal>
        </div>
      </Reveal>
    </div>
  );
};

const Row: React.FC<{label: string; value: string; color: string; bold?: boolean}> = ({
  label, value, color, bold,
}) => (
  <div style={{
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'baseline',
    paddingBlock: 12,
  }}>
    <span style={{
      fontFamily: fonts.body,
      fontSize: 17,
      color: palette.inkMuted,
      fontWeight: 500,
      letterSpacing: '0.06em',
      textTransform: 'uppercase',
    }}>
      {label}
    </span>
    <span style={{
      fontFamily: fonts.display,
      fontSize: bold ? 32 : 24,
      color,
      fontWeight: bold ? 700 : 500,
      letterSpacing: '-0.02em',
      fontVariantNumeric: 'tabular-nums',
    }}>
      {value}
    </span>
  </div>
);

const Hairline: React.FC = () => (
  <div style={{height: 1, backgroundColor: palette.rule, opacity: 0.6}} />
);

// ============================================================================
// Phase C — Win-win punchline
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

  return (
    <AbsoluteFill
      style={{opacity, alignItems: 'center', justifyContent: 'center', pointerEvents: 'none'}}
    >
      <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 36, maxWidth: 1500}}>
        <Reveal delaySec={startSec + 0.4}>
          <div style={{
            fontFamily: fonts.body,
            fontSize: 22,
            color: palette.red,
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            fontWeight: 600,
          }}>
            The mechanism
          </div>
        </Reveal>
        <Reveal delaySec={startSec + 1.2}>
          <div style={{
            fontFamily: fonts.display,
            fontSize: 52,
            color: palette.ink,
            fontWeight: 500,
            letterSpacing: '-0.025em',
            lineHeight: 1.25,
            textAlign: 'center',
          }}>
            Large firms{' '}
            <span style={{color: palette.blue, fontWeight: 600}}>stay</span>
            {' '}in the room.
            <br />
            They keep the runner-up{' '}
            <span style={{color: palette.red, fontWeight: 600}}>tough.</span>
            <br />
            SMEs are{' '}
            <span style={{color: palette.red, fontWeight: 600}}>forced</span>
            {' '}to bid hard.
          </div>
        </Reveal>
        <Reveal delaySec={startSec + 7.5}>
          <div style={{
            marginTop: 24,
            fontFamily: fonts.display,
            fontSize: 32,
            color: palette.ink,
            fontWeight: 500,
            letterSpacing: '-0.02em',
            fontStyle: 'italic',
            textAlign: 'center',
            lineHeight: 1.4,
          }}>
            The SME preference at{' '}
            <span style={{color: palette.red, fontWeight: 700, fontStyle: 'normal'}}>
              near-zero fiscal cost.
            </span>
          </div>
        </Reveal>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// Main scene
// ============================================================================
export const PolicyWindow: React.FC = () => {
  return (
    <Frame>
      <Chrome />
      <PhaseA />
      <PhaseB />
      <PhaseC />
    </Frame>
  );
};
