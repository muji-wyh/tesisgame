const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { runGodot } = require('./run-godot.cjs');

const root = path.resolve(__dirname, '..');
const groups = {
  jelly: { godot: ['jelly_match_model_tests', 'jelly_match_view_tests', 'jelly_match_flow_tests', 'jelly_match_audio_tests', 'pop_reward_room_tests'], node: ['jelly-host'] },
  growth: { godot: ['growth_state_tests', 'growth_flow_tests', 'pip_growth_tests'], node: ['growth-host', 'growth-vocabulary'] },
  core: {
    godot: [
      'run_tests', 'adventure_model_tests', 'adventure_scene_tests', 'medal_progress_tests',
      'medal_scene_tests', 'voice_model_tests', 'match_voice_feedback_tests', 'mascot_tests', 'mascot_redraw_tests', 'playful_controls_tests',
      'expansion_scene_tests', 'lesson_scene_tests',
      'lesson_navigation_tests', 'memory_model_tests', 'memory_garden_tests',
      'memory_peek_tests', 'memory_scene_tests', 'ui_audio_flow_tests', 'ui_click_tests', 'ui_recovery_tests',
      'phrase_model_tests', 'phrase_scene_tests'
    ],
    node: [
      'assets', 'chest-assets', 'web-export', 'web-scrollbars', 'voice-generation', 'deployment', 'memory-input-host',
      'unity-art', 'test-runner', 'web-package-cache', 'web-build-receipt', 'performance-benchmark', 'ui-click-assets', 'interface-click-host'
    ]
  },
  flow: {
    godot: [
      'steady_match_tests', 'layout_tests', 'three_mode_tests', 'layout_finish_tests',
      'collection_polish_tests', 'navigation_removal_tests', 'scroll_momentum_tests', 'pip_mode_menu_tests', 'scrollbar_visibility_tests', 'theme_review_tests',
      'presentation_tests', 'playful_words_tests'
    ]
  },
  ages: { godot: ['age_level_tests', 'vocabulary_layout_tests', 'age_scene_tests', 'age_word_catalog_tests'] },
  cards: { godot: ['card_polish_tests'] },
  'match-groups': { godot: ['match_groups_tests', 'match_connections_tests'] },
  'hint-link': { godot: ['hint_link_tests'] },
  'playful-ui': {
    godot: [
      'memory_back_design_tests', 'playful_affordance_tests', 'proactive_pip_tests',
      'pip_engagement_scene_tests'
    ]
  },
  'voice-pop': {
    godot: ['voice_pop_model_tests', 'voice_pop_scene_tests', 'voice_pop_reward_tests', 'pop_reward_room_tests', 'pop_reward_flow_tests', 'pop_treasure_scroll_tests', 'result_scroll_tests', 'voice_pop_slice_tests', 'voice_pop_audio_tests', 'pop_result_audio_tests'],
    node: ['voice-host', 'local-speech-host', 'speech-debug-host', 'voice-pop-reference-assets', 'pop-reward-host']
  },
  'layout-release': { godot: ['layout_release_tests'] },
  themes: { godot: ['new_theme_tests', 'pip_outfit_tests'], node: ['pip-wardrobe', 'world-audio'] },
  'pip-audio': { godot: ['pip_audio_tests', 'pip_reaction_audio_tests'] },
  'pip-feedback': { godot: ['pip_gameplay_motion_tests', 'pip_gameplay_feedback_tests', 'pip_expression_tests',
    'round_celebration_tests', 'round_celebration_audio_tests', 'round_celebration_flow_tests'] },
  'chest-charge': { godot: ['chest_models_tests', 'chest_reveal_tests', 'chest_feel_tests', 'chest_audio_tests', 'chest_charge_flow_tests', 'chest_surprise_tests'] }
};

const allGroups = Object.keys(groups);

function createPlan(names = ['all']) {
  const godot = new Set(), node = new Set();
  for (const name of names.flatMap(name => name === 'all' ? allGroups : [name])) {
    if (!Object.hasOwn(groups, name)) {
      throw new Error(`Unknown test group: ${name}. Choose all or ${allGroups.join(', ')}.`);
    }
    for (const suite of groups[name].godot || []) godot.add(suite);
    for (const suite of groups[name].node || []) node.add(`tests/${suite}.test.cjs`);
  }
  return {
    godot: [...godot].map(suite => ({
      file: `tests/godot/${suite}.gd`,
      options: suite === 'vocabulary_layout_tests' ? ['--fixed-fps', '60'] : []
    })),
    node: [...node]
  };
}

function runTests(plan) {
  for (const [index, suite] of plan.godot.entries()) {
    console.log(`\n[Godot ${index + 1}/${plan.godot.length}] ${suite.file}`);
    // The vocabulary layout suite checks all 1,550 labels and representative scenes at six sizes.
    const timeout = suite.file.endsWith('/vocabulary_layout_tests.gd') ? 600000 : 180000;
    const result = runGodot(['--headless', ...suite.options, '--path', '.', '--script', `res://${suite.file}`], { timeout });
    process.stdout.write(result.stdout || '');
    process.stderr.write(result.stderr || '');
  }
  if (plan.node.length) {
    console.log(`\n[Node] ${plan.node.length} suites:\n${plan.node.join('\n')}`);
    const result = spawnSync(process.execPath, ['--test', ...plan.node], {
      cwd: root, stdio: 'inherit', windowsHide: true
    });
    if (result.error) throw new Error(`Could not run Node tests: ${result.error.message}`, { cause: result.error });
    if (result.signal) throw new Error(`Node tests stopped by ${result.signal}.`);
    if (result.status !== 0) return result.status || 1;
  }
  console.log(`\nPassed ${plan.godot.length} Godot suites and ${plan.node.length} Node suites.`);
  return 0;
}

module.exports = { groups, allGroups, createPlan };

if (require.main === module) {
  try {
    const args = process.argv.slice(2);
    const names = args.filter(arg => arg !== '--list');
    const plan = createPlan(names.length ? names : ['all']);
    if (args.includes('--list')) {
      for (const suite of plan.godot) console.log(`Godot: ${suite.file}${suite.options.length ? ` (${suite.options.join(' ')})` : ''}`);
      for (const file of plan.node) console.log(`Node: ${file}`);
    } else {
      process.exitCode = runTests(plan);
    }
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
