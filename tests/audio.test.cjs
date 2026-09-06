const test = require('node:test');
const assert = require('node:assert/strict');
const { loadInline } = require('.\\load-inline.cjs');

const themes = loadInline('game-core').GameCore.SEASONS;
const audio = loadInline('game-audio').GameAudio;

function fixture(rejectPlay = false, rejectResume = false) {
  const instances = [];
  const statuses = [];
  const contexts = [];
  class Context {
    constructor() {
      this.state = 'suspended';
      this.currentTime = 0;
      this.destination = {};
      this.sources = [];
      this.gains = [];
      contexts.push(this);
    }
    resume() {
      if (rejectResume) return Promise.reject(new Error('Audio context blocked'));
      this.state = 'running';
      return Promise.resolve();
    }
    createGain() {
      const node = {
        gain: {
          value: 1,
          setTargetAtTime(value) { this.value = value; }
        },
        connect(destination) { this.destination = destination; }
      };
      this.gains.push(node);
      return node;
    }
    createMediaElementSource(element) {
      const source = {
        element,
        connect(destination) { this.destination = destination; }
      };
      this.sources.push(source);
      return source;
    }
  }
  class Media {
    constructor() {
      this.src = '';
      this.paused = true;
      this.readyState = 4;
      this.currentTime = 0;
      this.error = null;
      this.events = {};
      this.plays = 0;
      this.loads = 0;
      Object.defineProperty(this, 'volume', { get: () => 1, set() {} });
      instances.push(this);
    }
    addEventListener(name, callback) { this.events[name] = callback; }
    play() {
      this.plays += 1;
      if (rejectPlay) {
        this.paused = true;
        return Promise.reject(Object.assign(new Error('blocked'), { name: 'NotAllowedError' }));
      }
      this.paused = false;
      this.events.playing?.();
      return Promise.resolve();
    }
    pause() { this.paused = true; this.events.pause?.(); }
    load() { this.loads += 1; this.error = null; }
  }
  const controller = audio.createController(
    { Audio: Media, AudioContext: Context, console: { warn() {} } },
    (message) => statuses.push(message), themes
  );
  return { controller, instances, statuses, contexts };
}

test('starts silent, then plays the selected word and current theme music', () => {
  const f = fixture();
  f.controller.handle({ type: 'reset', theme: 'spring' });
  assert.equal(f.instances.length, 0);
  f.controller.handle({ type: 'select', voice: 'assets/audio/voice/word-cat.wav' });
  assert.ok(f.instances.some((media) => media.src.endsWith('word-cat.wav') && !media.paused));
  assert.ok(f.instances.some((media) => media.src.endsWith('bgm/spring.wav') && media.loop));
});

test('each season uses its own music, entry sound, opening sound and voice', () => {
  for (const theme of themes) {
    const f = fixture();
    f.controller.handle({ type: 'reset', theme: theme.id });
    f.controller.handle({ type: 'win', theme: theme.id });
    assert.ok(f.instances.some((media) => media.src.endsWith(`sfx/${theme.id}-arrive.wav`)));
    f.controller.handle({ type: 'open', theme: theme.id });
    assert.ok(f.instances.some((media) => media.src.endsWith(`sfx/${theme.id}-open.wav`)));
    assert.ok(f.instances.some((media) => media.src.endsWith(`voice/${theme.id}-open.wav`)));
    assert.equal(f.instances.length, 3);
  }
});

test('changing themes replaces background music without adding players', () => {
  const f = fixture();
  f.controller.handle({ type: 'reset', theme: 'spring' });
  f.controller.handle({ type: 'select', voice: 'assets/audio/voice/word-cat.wav' });
  f.controller.handle({ type: 'theme', theme: 'winter' });
  assert.equal(f.instances.length, 3);
  assert.ok(f.instances.some((media) => media.loop && media.src.endsWith('winter.wav') && !media.paused));
  assert.ok(f.instances.some((media) => media.src.endsWith('voice/winter-theme.wav')));
});

test('mute, reset and hiding stop all channels; returning does not autoplay', () => {
  const f = fixture();
  f.controller.handle({ type: 'reset', theme: 'summer' });
  f.controller.handle({ type: 'listen' });
  f.controller.handle({ type: 'mute', muted: true });
  const plays = f.instances.reduce((sum, media) => sum + media.plays, 0);
  f.controller.handle({ type: 'open', theme: 'summer' });
  assert.equal(f.instances.reduce((sum, media) => sum + media.plays, 0), plays);
  assert.ok(f.instances.every((media) => media.paused));
  f.controller.handle({ type: 'mute', muted: false });
  f.controller.handle({ type: 'visibility', hidden: true });
  assert.ok(f.instances.every((media) => media.paused));
  f.controller.handle({ type: 'visibility', hidden: false });
  assert.ok(f.instances.every((media) => media.paused));
  f.controller.handle({ type: 'listen' });
  assert.ok(f.instances.some((media) => !media.paused));
  f.controller.handle({ type: 'reset', theme: 'winter' });
  assert.ok(f.instances.every((media) => media.paused));
});

test('failure stops music and plays the prerecorded encouragement', () => {
  const f = fixture();
  f.controller.handle({ type: 'reset', theme: 'autumn' });
  f.controller.handle({ type: 'listen' });
  f.controller.handle({ type: 'loss' });
  assert.ok(f.instances.find((media) => media.loop).paused);
  assert.ok(f.instances.some((media) => media.src.endsWith('voice/loss.wav') && !media.paused));
});

test('playback failures are visible but canceled playback cannot pollute a reset', async () => {
  const f = fixture(true);
  f.controller.handle({ type: 'reset', theme: 'spring' });
  f.controller.handle({ type: 'listen' });
  await Promise.resolve();
  await Promise.resolve();
  assert.ok(f.statuses.some((text) => text.includes('Listen')));
  const g = fixture(true);
  g.controller.handle({ type: 'reset', theme: 'spring' });
  g.controller.handle({ type: 'listen' });
  g.controller.handle({ type: 'reset', theme: 'winter' });
  await Promise.resolve();
  await Promise.resolve();
  assert.equal(g.statuses.at(-1), '');
  assert.throws(() => g.controller.handle({ type: 'unknown' }), { name: 'RangeError' });
});

test('media loading errors are visible while active but ignored after a reset', async () => {
  const f = fixture();
  f.controller.handle({ type: 'reset', theme: 'spring' });
  f.controller.handle({ type: 'listen' });
  await Promise.resolve();
  const voice = f.instances.find((media) => media.src.includes('/voice/'));
  voice.error = { code: 4 };
  voice.events.error();
  assert.ok(f.statuses.at(-1).includes('Voice'));
  f.controller.handle({ type: 'reset', theme: 'summer' });
  voice.events.error();
  assert.equal(f.statuses.at(-1), '');
});

test('Listen reloads failed music even if paused is still false', () => {
  const f = fixture();
  f.controller.handle({ type: 'reset', theme: 'spring' });
  f.controller.handle({ type: 'listen' });
  const music = f.instances.find((media) => media.loop);
  const plays = music.plays;
  music.error = { code: 2 };
  music.paused = false;
  music.events.error();
  f.controller.handle({ type: 'listen' });
  assert.equal(music.loads, 1);
  assert.equal(music.plays, plays + 1);
  assert.equal(music.error, null);
});

test('gain nodes balance and duck sound when iOS ignores media volume', () => {
  const f = fixture();
  f.controller.handle({ type: 'reset', theme: 'spring' });
  assert.equal(f.contexts.length, 0);
  f.controller.handle({ type: 'select', voice: 'assets/audio/voice/word-cat.wav' });
  assert.equal(f.contexts.length, 1);
  const context = f.contexts[0];
  assert.equal(context.sources.length, 3);
  const music = context.sources.find((source) => source.element.loop);
  const voice = context.sources.find((source) => source.element.src.includes('/voice/'));
  assert.equal(music.element.volume, 1);
  assert.equal(music.destination.gain.value, 0.05);
  assert.equal(voice.destination.gain.value, 0.8);
  assert.equal(music.destination.destination.gain.value, 0.8);
  voice.element.paused = true;
  voice.element.events.ended();
  assert.equal(music.destination.gain.value, 0.15);
});

test('blocked audio context is reported without stale errors after resetting', async () => {
  const f = fixture(false, true);
  f.controller.handle({ type: 'reset', theme: 'spring' });
  f.controller.handle({ type: 'listen' });
  await Promise.resolve();
  await Promise.resolve();
  assert.ok(f.statuses.at(-1).includes('Listen'));
  const g = fixture(false, true);
  g.controller.handle({ type: 'reset', theme: 'spring' });
  g.controller.handle({ type: 'listen' });
  g.controller.handle({ type: 'reset', theme: 'winter' });
  await Promise.resolve();
  await Promise.resolve();
  assert.equal(g.statuses.at(-1), '');
});
