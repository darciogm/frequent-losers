/**
 * Google Fonts loaded via Remotion's font loader. Importing this module
 * triggers the network fetch + face registration during bundling, so
 * by the time scenes render the typography is correct.
 */

import {loadFont as loadInter} from '@remotion/google-fonts/Inter';
import {loadFont as loadRobotoSlab} from '@remotion/google-fonts/RobotoSlab';
import {loadFont as loadJetBrains} from '@remotion/google-fonts/JetBrainsMono';

const inter = loadInter('normal', {
  weights: ['400', '500', '600', '700'],
});
const slab = loadRobotoSlab('normal', {
  weights: ['400', '500', '600', '700'],
});
const mono = loadJetBrains('normal', {
  weights: ['400', '500'],
});

export const fontFamilies = {
  body: inter.fontFamily,
  display: slab.fontFamily,
  mono: mono.fontFamily,
} as const;

export const waitForFonts = () =>
  Promise.all([inter.waitUntilDone(), slab.waitUntilDone(), mono.waitUntilDone()]);
