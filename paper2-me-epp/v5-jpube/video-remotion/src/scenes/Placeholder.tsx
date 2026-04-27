import React from 'react';
import {AbsoluteFill, useCurrentFrame, useVideoConfig, interpolate} from 'remotion';
import {Frame, Header} from '../components/Frame';
import {palette, fonts, sizes} from '../lib/theme';

/**
 * Placeholder scene — used while individual scenes are being designed.
 * Renders the scene id and a slow-pulsing dot so playback timing can
 * still be validated against the audio track.
 */
export const Placeholder: React.FC<{
  sceneId: string;
  title: string;
}> = ({sceneId, title}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const pulse = 0.5 + 0.5 * Math.sin((frame / fps) * Math.PI);

  return (
    <Frame>
      <Header />
      <AbsoluteFill
        style={{
          alignItems: 'center',
          justifyContent: 'center',
          flexDirection: 'column',
          gap: 32,
        }}
      >
        <div
          style={{
            width: 16,
            height: 16,
            borderRadius: 8,
            backgroundColor: palette.red,
            opacity: 0.3 + pulse * 0.5,
          }}
        />
        <div
          style={{
            fontFamily: fonts.body,
            fontSize: sizes.caption,
            color: palette.inkMuted,
            letterSpacing: '0.08em',
            textTransform: 'uppercase',
            fontWeight: 500,
          }}
        >
          Scene · {sceneId}
        </div>
        <div
          style={{
            fontFamily: fonts.display,
            fontSize: sizes.large,
            color: palette.ink,
            letterSpacing: '-0.02em',
            fontWeight: 600,
          }}
        >
          {title}
        </div>
        <div
          style={{
            fontFamily: fonts.body,
            fontSize: sizes.caption,
            color: palette.inkSoft,
            opacity: 0.6,
            marginTop: 24,
          }}
        >
          (placeholder — final design in progress)
        </div>
      </AbsoluteFill>
    </Frame>
  );
};
