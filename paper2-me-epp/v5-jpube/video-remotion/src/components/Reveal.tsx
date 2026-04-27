import React from 'react';
import {useCurrentFrame, useVideoConfig, interpolate, Easing} from 'remotion';

/**
 * Stagger-reveal helper. Mounts content invisible, then fades in with a
 * 14 px upward translate over `durSec`, starting at `delaySec`. Easing
 * curve is the Vercel/Linear "out-expo" feel that makes UI motion read
 * as designed rather than scripted.
 */
export const Reveal: React.FC<{
  delaySec?: number;
  durSec?: number;
  ty?: number;
  tx?: number;
  children: React.ReactNode;
  /** When set, also fades out starting at exitSec. */
  exitSec?: number;
  exitDurSec?: number;
}> = ({
  delaySec = 0,
  durSec = 0.7,
  ty = 14,
  tx = 0,
  children,
  exitSec,
  exitDurSec = 0.5,
}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const enterStart = delaySec * fps;
  const enterEnd = enterStart + durSec * fps;
  const tIn = interpolate(frame, [enterStart, enterEnd], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });

  let tOut = 1;
  if (exitSec !== undefined) {
    const exitStart = exitSec * fps;
    const exitEnd = exitStart + exitDurSec * fps;
    tOut = interpolate(frame, [exitStart, exitEnd], [1, 0], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
      easing: Easing.bezier(0.16, 1, 0.3, 1),
    });
  }

  const t = tIn * tOut;
  return (
    <div
      style={{
        opacity: t,
        transform: `translate(${(1 - tIn) * tx}px, ${(1 - tIn) * ty}px)`,
      }}
    >
      {children}
    </div>
  );
};
