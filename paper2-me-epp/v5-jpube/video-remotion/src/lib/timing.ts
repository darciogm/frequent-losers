/**
 * Scene timing — calibrated against the NotebookLM transcript so each
 * scene's duration matches the slice of audio it accompanies.
 *
 * Scene 09 (CMED double-regulation) is intentionally absent: NotebookLM
 * did not cover that topic in the audio. Scene 06 (decomposition
 * centerpiece) plays BEFORE Scene 05 (drop-out trick) because the
 * hosts present the result first, then explain identification.
 */

import {sec, layout} from './theme';

export type SceneSpec = {
  id: string;
  startSec: number;
  durationSec: number;
};

export const SCENES: SceneSpec[] = [
  {id: 'cold_open',          startSec:    0, durationSec:  54},
  {id: 'question',           startSec:   54, durationSec:  80},
  {id: 'natural_experiment', startSec:  134, durationSec: 196},
  {id: 'data',               startSec:  330, durationSec:  43},
  {id: 'model',              startSec:  373, durationSec: 177},
  {id: 'decomposition',      startSec:  550, durationSec: 152},
  {id: 'dropout',            startSec:  702, durationSec:  96},
  {id: 'welfare_lambda',     startSec:  798, durationSec:  81},
  {id: 'policy_window',      startSec:  879, durationSec:  51},
  {id: 'closing',            startSec:  930, durationSec:  83},
];

export const TOTAL_SEC = SCENES.reduce(
  (m, s) => Math.max(m, s.startSec + s.durationSec),
  0,
);
export const TOTAL_FRAMES = sec(TOTAL_SEC);

/** Look up a scene's frame range. */
export const sceneRange = (id: string) => {
  const s = SCENES.find((x) => x.id === id);
  if (!s) throw new Error(`Unknown scene id: ${id}`);
  return {from: sec(s.startSec), durationInFrames: sec(s.durationSec)};
};
