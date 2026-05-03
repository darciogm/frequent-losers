import React from 'react';
import {useCurrentFrame, useVideoConfig, interpolate, Easing} from 'remotion';
import {palette, fonts} from '../lib/theme';

/**
 * Persistent editorial chrome shared across every scene: red-bar eyebrow
 * top-left, paper title top-right, byline + URL hairline footer. Mirrors
 * the running-header convention of a long-form magazine open.
 */
export const Chrome: React.FC<{
  /** Override the eyebrow label (default "PROCUREMENT ECONOMICS"). */
  eyebrow?: string;
  /** Hide the bottom footer (rare; only in scenes that need full-bleed). */
  hideFooter?: boolean;
  /** Delay before chrome fades in, in seconds. */
  enterDelaySec?: number;
}> = ({
  eyebrow = 'Procurement economics',
  hideFooter = false,
  enterDelaySec = 0,
}) => {
  const frame = useCurrentFrame();
  const {fps, durationInFrames} = useVideoConfig();
  const start = enterDelaySec * fps;
  const opacity = interpolate(
    frame,
    [start, start + fps * 0.6, durationInFrames - fps * 0.6, durationInFrames],
    [0, 1, 1, 0],
    {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
      easing: Easing.bezier(0.16, 1, 0.3, 1),
    },
  );

  return (
    <>
      {/* Top row */}
      <div
        style={{
          position: 'absolute',
          top: 64,
          left: 96,
          right: 96,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          opacity,
          fontFamily: fonts.body,
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 18,
            fontSize: 22,
            color: palette.red,
            letterSpacing: '0.18em',
            textTransform: 'uppercase',
            fontWeight: 600,
          }}
        >
          <span
            style={{
              display: 'inline-block',
              width: 36,
              height: 2,
              backgroundColor: palette.red,
            }}
          />
          {eyebrow}
        </div>

        <div
          style={{
            fontSize: 20,
            color: palette.inkMuted,
            letterSpacing: '0.06em',
            textTransform: 'uppercase',
            fontWeight: 500,
          }}
        >
          The Cost of Inclusion
        </div>
      </div>

      {/* Bottom row */}
      {!hideFooter && (
        <div
          style={{
            position: 'absolute',
            bottom: 72,
            left: 96,
            right: 96,
            opacity,
          }}
        >
          <div
            style={{
              borderTop: `1px solid ${palette.rule}`,
              paddingTop: 18,
              display: 'flex',
              justifyContent: 'space-between',
              fontFamily: fonts.body,
              fontSize: 18,
              color: palette.inkMuted,
              letterSpacing: '0.02em',
            }}
          >
            <span>Genicolo-Martins · Insper · 2026</span>
            <span style={{fontVariantNumeric: 'tabular-nums'}}>
              darciogm.github.io / research / sme-public
            </span>
          </div>
        </div>
      )}
    </>
  );
};
