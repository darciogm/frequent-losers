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
import {palette, fonts} from '../lib/theme';

/**
 * Scene 10 — Closing. 83-second scene structured in four phases:
 *
 *   A (0-30s)  Three takeaways — the recap.
 *   B (30-50s) Two questions a citizen should now ask about any
 *              set-aside policy.
 *   C (50-72s) The sandbox paradox — the provocative open question.
 *   D (72-83s) Sign-off — paper title returns + citation footer.
 */

const PHASE = {
  A_END: 30,
  B_END: 50,
  C_END: 72,
  D_END: 83,
} as const;

// ============================================================================
// Phase A — Three takeaways
// ============================================================================
const PhaseA: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const exit = interpolate(frame, [(PHASE.A_END - 2) * fps, PHASE.A_END * fps], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const items = [
    {
      n: '01',
      headline: 'The SME-only rule raises prices about 11%.',
      sub: 'A pristine quasi-experiment in São Paulo medical supplies.',
      delay: 1.5,
    },
    {
      n: '02',
      headline: '~74% runs through bid behavior, not entry.',
      sub: 'Sheltered SMEs face only other SMEs. They stop fighting.',
      delay: 8.5,
    },
    {
      n: '03',
      headline: 'A 10% price preference fixes most of it.',
      sub: 'Large firms stay in the room. The fiscal cost approaches zero.',
      delay: 16.5,
    },
  ];

  return (
    <div style={{opacity: exit, position: 'absolute', inset: 0, pointerEvents: 'none'}}>
      <Reveal delaySec={0.4}>
        <div style={{
          position: 'absolute',
          top: 200, left: 0, right: 0,
          textAlign: 'center',
          fontFamily: fonts.body,
          fontSize: 22,
          color: palette.red,
          letterSpacing: '0.18em',
          textTransform: 'uppercase',
          fontWeight: 600,
        }}>
          Three takeaways
        </div>
      </Reveal>

      <div style={{
        position: 'absolute',
        top: 300, left: 240, right: 240,
        display: 'flex',
        flexDirection: 'column',
        gap: 36,
      }}>
        {items.map((it) => (
          <Reveal key={it.n} delaySec={it.delay} ty={20}>
            <div style={{
              display: 'flex',
              alignItems: 'flex-start',
              gap: 56,
              borderTop: `1px solid ${palette.rule}`,
              paddingTop: 24,
            }}>
              <div style={{
                fontFamily: fonts.display,
                fontSize: 42,
                color: palette.red,
                fontWeight: 600,
                fontVariantNumeric: 'tabular-nums',
                minWidth: 80,
                lineHeight: 1,
              }}>
                {it.n}
              </div>
              <div style={{flex: 1}}>
                <div style={{
                  fontFamily: fonts.display,
                  fontSize: 40,
                  color: palette.ink,
                  fontWeight: 500,
                  letterSpacing: '-0.02em',
                  lineHeight: 1.2,
                  marginBottom: 8,
                }}>
                  {it.headline}
                </div>
                <div style={{
                  fontFamily: fonts.body,
                  fontSize: 22,
                  color: palette.inkSoft,
                  fontWeight: 400,
                  letterSpacing: '-0.005em',
                  fontStyle: 'italic',
                }}>
                  {it.sub}
                </div>
              </div>
            </div>
          </Reveal>
        ))}
      </div>
    </div>
  );
};

// ============================================================================
// Phase B — Two questions
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

  return (
    <AbsoluteFill style={{opacity, alignItems: 'center', justifyContent: 'center', pointerEvents: 'none'}}>
      <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 40, maxWidth: 1500}}>
        <Reveal delaySec={startSec + 0.4}>
          <div style={{
            fontFamily: fonts.body,
            fontSize: 22,
            color: palette.red,
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            fontWeight: 600,
          }}>
            The questions to ask
          </div>
        </Reveal>
        <Reveal delaySec={startSec + 1.0}>
          <div style={{
            fontFamily: fonts.display,
            fontSize: 38,
            color: palette.inkSoft,
            fontWeight: 400,
            letterSpacing: '-0.02em',
            textAlign: 'center',
            fontStyle: 'italic',
            marginBottom: 20,
          }}>
            Next time you hear about a "buy local" or "SME-only" rule —
          </div>
        </Reveal>

        <Reveal delaySec={startSec + 4.5} ty={18}>
          <div style={{
            fontFamily: fonts.display,
            fontSize: 50,
            color: palette.ink,
            fontWeight: 500,
            letterSpacing: '-0.025em',
            textAlign: 'center',
            lineHeight: 1.25,
            maxWidth: 1500,
          }}>
            Total exclusion, or{' '}
            <span style={{color: palette.red, fontWeight: 600}}>
              price preference?
            </span>
          </div>
        </Reveal>

        <Reveal delaySec={startSec + 10.5} ty={18}>
          <div style={{
            fontFamily: fonts.display,
            fontSize: 50,
            color: palette.ink,
            fontWeight: 500,
            letterSpacing: '-0.025em',
            textAlign: 'center',
            lineHeight: 1.25,
            maxWidth: 1500,
            marginTop: 16,
          }}>
            Who's the{' '}
            <span style={{color: palette.red, fontWeight: 600}}>
              runner-up
            </span>{' '}
            setting the price?
          </div>
        </Reveal>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// Phase C — Sandbox paradox
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
    <AbsoluteFill style={{opacity, alignItems: 'center', justifyContent: 'center', pointerEvents: 'none'}}>
      <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 36, maxWidth: 1500}}>
        <Reveal delaySec={startSec + 0.4}>
          <div style={{
            fontFamily: fonts.body,
            fontSize: 22,
            color: palette.amber,
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            fontWeight: 600,
          }}>
            One final thought
          </div>
        </Reveal>
        <Reveal delaySec={startSec + 1.2}>
          <div style={{
            fontFamily: fonts.display,
            fontSize: 60,
            color: palette.ink,
            fontWeight: 600,
            letterSpacing: '-0.03em',
            textAlign: 'center',
            lineHeight: 1.15,
            maxWidth: 1500,
            fontStyle: 'italic',
          }}>
            The sandbox paradox.
          </div>
        </Reveal>
        <Reveal delaySec={startSec + 5.0}>
          <div style={{
            marginTop: 24,
            fontFamily: fonts.display,
            fontSize: 36,
            color: palette.inkSoft,
            fontWeight: 400,
            letterSpacing: '-0.02em',
            textAlign: 'center',
            lineHeight: 1.4,
            maxWidth: 1500,
          }}>
            If SMEs are permanently shielded
            <br />
            from racing against the fastest runners —
          </div>
        </Reveal>
        <Reveal delaySec={startSec + 12.0}>
          <div style={{
            marginTop: 18,
            fontFamily: fonts.display,
            fontSize: 38,
            color: palette.red,
            fontWeight: 600,
            letterSpacing: '-0.025em',
            textAlign: 'center',
            lineHeight: 1.35,
            maxWidth: 1500,
            fontStyle: 'italic',
          }}>
            do they ever grow into the giants
            <br />
            the policy was meant to challenge?
          </div>
        </Reveal>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// Phase D — Sign-off
// ============================================================================
const PhaseD: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const startSec = PHASE.C_END;
  const enter = spring({
    frame: Math.max(0, frame - startSec * fps),
    fps,
    config: {damping: 200, stiffness: 80, mass: 0.6},
  });
  const exit = interpolate(
    frame,
    [(PHASE.D_END - 2) * fps, PHASE.D_END * fps],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  const opacity = enter * exit;

  return (
    <AbsoluteFill style={{
      opacity,
      alignItems: 'center',
      justifyContent: 'center',
      pointerEvents: 'none',
    }}>
      <div style={{
        transform: `translateY(${(1 - enter) * 18}px)`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 30,
      }}>
        <div style={{
          fontFamily: fonts.body,
          fontSize: 22,
          color: palette.inkMuted,
          letterSpacing: '0.18em',
          textTransform: 'uppercase',
          fontWeight: 500,
        }}>
          Working paper · Insper · 2026
        </div>
        <div style={{
          fontFamily: fonts.display,
          fontSize: 96,
          color: palette.ink,
          fontWeight: 700,
          letterSpacing: '-0.035em',
          lineHeight: 1.05,
          textAlign: 'center',
        }}>
          The Cost of Inclusion
        </div>
        <div style={{
          fontFamily: fonts.body,
          fontSize: 28,
          color: palette.inkSoft,
          fontWeight: 400,
          letterSpacing: '-0.005em',
        }}>
          Darcio Genicolo-Martins
        </div>
        <div style={{
          width: 96,
          height: 1,
          backgroundColor: palette.rule,
          marginTop: 12,
          marginBottom: 12,
        }} />
        <div style={{
          fontFamily: fonts.body,
          fontSize: 24,
          color: palette.red,
          fontWeight: 600,
          letterSpacing: '0.02em',
        }}>
          darciogm.github.io / research / sme-public
        </div>
      </div>
    </AbsoluteFill>
  );
};

// ============================================================================
// Main scene
// ============================================================================
export const Closing: React.FC = () => {
  return (
    <Frame>
      {/* Chrome only during phases A/B/C; faded out during D for the sign-off */}
      <ChromeFader />
      <PhaseA />
      <PhaseB />
      <PhaseC />
      <PhaseD />
    </Frame>
  );
};

const ChromeFader: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const opacity = interpolate(
    frame,
    [PHASE.C_END * fps - fps * 0.5, PHASE.C_END * fps + fps * 0.5],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
  return (
    <div style={{opacity}}>
      <Chrome />
    </div>
  );
};
