import React from 'react';
import {Composition, Audio, Sequence, staticFile} from 'remotion';
import {layout, sec} from './lib/theme';
import {SCENES, TOTAL_FRAMES, sceneRange} from './lib/timing';
import {ColdOpen} from './scenes/ColdOpen';
import {Question} from './scenes/Question';
import {NaturalExperiment} from './scenes/NaturalExperiment';
import {Data} from './scenes/Data';
import {Model} from './scenes/Model';
import {Decomposition} from './scenes/Decomposition';
import {Dropout} from './scenes/Dropout';
import {WelfareLambda} from './scenes/WelfareLambda';
import {PolicyWindow} from './scenes/PolicyWindow';
import {Closing} from './scenes/Closing';
import {Placeholder} from './scenes/Placeholder';

const SCENE_TITLES: Record<string, string> = {
  cold_open:          'R$ 50–85 million',
  question:           'The question',
  natural_experiment: 'March 2018 reinterpretation',
  data:               'Sample funnel',
  model:              'The model in one line',
  decomposition:      'Intensive vs. extensive margin',
  dropout:            'The drop-out trick',
  welfare_lambda:     'Welfare and λ',
  policy_window:      'A 10% price preference',
  closing:            'Three contributions',
};

/** Map scene id → React component. ColdOpen is the proof-of-concept;
 *  the rest fall back to Placeholder while the final designs land. */
const SceneComponent: React.FC<{id: string}> = ({id}) => {
  switch (id) {
    case 'cold_open':
      return <ColdOpen />;
    case 'question':
      return <Question />;
    case 'natural_experiment':
      return <NaturalExperiment />;
    case 'data':
      return <Data />;
    case 'model':
      return <Model />;
    case 'decomposition':
      return <Decomposition />;
    case 'dropout':
      return <Dropout />;
    case 'welfare_lambda':
      return <WelfareLambda />;
    case 'policy_window':
      return <PolicyWindow />;
    case 'closing':
      return <Closing />;
    default:
      return <Placeholder sceneId={id} title={SCENE_TITLES[id] ?? id} />;
  }
};

export const Video: React.FC = () => {
  return (
    <>
      {/* NotebookLM podcast track plays end-to-end across all scenes */}
      <Audio src={staticFile('notebooklm.m4a')} />

      {SCENES.map((s) => {
        const range = sceneRange(s.id);
        return (
          <Sequence
            key={s.id}
            from={range.from}
            durationInFrames={range.durationInFrames}
            name={s.id}
          >
            <SceneComponent id={s.id} />
          </Sequence>
        );
      })}
    </>
  );
};

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="CostOfInclusion"
        component={Video}
        durationInFrames={TOTAL_FRAMES}
        fps={layout.fps}
        width={layout.width}
        height={layout.height}
      />
    </>
  );
};
