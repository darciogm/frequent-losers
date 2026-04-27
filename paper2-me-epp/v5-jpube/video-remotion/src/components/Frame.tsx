import React from 'react';
import {AbsoluteFill} from 'remotion';
import {palette, fonts} from '../lib/theme';

/**
 * Outer frame applied to every scene: paper background, body font,
 * and a subtle inner padding equal to the editorial margin. Each scene
 * is rendered inside this frame so safe-area math is consistent.
 */
export const Frame: React.FC<{children: React.ReactNode}> = ({children}) => (
  <AbsoluteFill
    style={{
      backgroundColor: palette.paper,
      color: palette.ink,
      fontFamily: fonts.body,
      fontFeatureSettings: '"ss01", "cv11", "tnum"',  // tabular nums + Inter ss
      letterSpacing: '-0.005em',
    }}
  >
    {children}
  </AbsoluteFill>
);

/**
 * Sticky paper-title strip in the top-left, matching the printed
 * paper's running header. Appears from Scene 1 onward.
 */
export const Header: React.FC<{visible?: boolean}> = ({visible = true}) => {
  if (!visible) return null;
  return (
    <div
      style={{
        position: 'absolute',
        top: 56,
        left: 96,
        fontFamily: fonts.body,
        fontSize: 22,
        fontWeight: 500,
        color: palette.inkSoft,
        letterSpacing: '-0.005em',
      }}
    >
      The Cost of Inclusion &nbsp;·&nbsp;{' '}
      <span style={{color: palette.inkMuted}}>
        Genicolo-Martins (2026)
      </span>
    </div>
  );
};
