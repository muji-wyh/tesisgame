const test = require('node:test');
const assert = require('node:assert/strict');
const { loadInline } = require('.\\load-inline.cjs');

const effects = loadInline('game-effects').GameEffects;

test('each theme produces a bounded, varied 72-particle celebration', () => {
  const variants = [];
  for (const id of ['spring', 'summer', 'autumn', 'winter']) {
    const particles = effects.createParticles(id, () => 0.4);
    assert.equal(particles.length, 72);
    assert.equal(particles.filter((p) => p.kind === 'token').length, 12);
    const tokens = particles.filter((p) => p.kind === 'token');
    assert.ok(Math.min(...tokens.map((p) => p.x)) < -0.4, 'Theme icons must spread left.');
    assert.ok(Math.max(...tokens.map((p) => p.x)) > 0.4, 'Theme icons must spread right.');
    assert.ok(Math.min(...tokens.map((p) => p.y)) < -0.3, 'Theme icons must spread upward.');
    assert.ok(Math.max(...tokens.map((p) => p.y)) > 0.3, 'Theme icons must spread downward.');
    assert.equal(new Set(particles.map((p) => p.kind)).size, 3);
    assert.ok(new Set(particles.map((p) => p.x)).size > 20);
    for (const particle of particles) {
      for (const key of ['x', 'y', 'endX', 'endY', 'size', 'spin', 'delay', 'duration']) {
        assert.ok(Number.isFinite(particle[key]), key);
      }
      assert.ok(particle.size >= 3 && particle.size <= 42);
      assert.ok(particle.delay + particle.duration < effects.EFFECT_MS);
      assert.match(particle.color, /^#[0-9a-f]{6}$/i);
    }
    variants.push(JSON.stringify(particles));
  }
  assert.equal(new Set(variants).size, 4);
  assert.ok(effects.OPEN_MS >= 1500 && effects.OPEN_MS <= 2200);
  assert.throws(() => effects.createParticles('unknown'), { name: 'RangeError' });
  assert.throws(() => effects.createParticles('spring', () => 1), { name: 'RangeError' });
});

function sceneFixture() {
  const timers = new Set();
  const callbacks = [];
  function element() {
    return {
      children: [],
      dataset: {},
      style: { setProperty() {}, removeProperty() {} },
      append(...children) { this.children.push(...children); },
      replaceChildren(...children) { this.children = children; },
      getBoundingClientRect: () => ({ width: 360, height: 440 })
    };
  }
  const module = loadInline('game-effects', {
    document: { createElement: element },
    setTimeout(callback) { timers.add(callback); callbacks.push(callback); return callback; },
    clearTimeout(callback) { timers.delete(callback); }
  }).GameEffects;
  return { module, container: element(), timers, callbacks };
}

test('a new celebration cancels the old one and cleanup cannot remove a newer scene', () => {
  const f = sceneFixture();
  const stopFirst = f.module.play(f.container, { id: 'spring', symbol: 'spring.svg' });
  assert.ok(f.container.children.length > 72);
  const stopSecond = f.module.play(f.container, { id: 'winter', symbol: 'winter.svg' });
  assert.equal(f.timers.size, 1);
  stopFirst();
  f.callbacks[0]();
  assert.equal(f.container.dataset.theme, 'winter');
  assert.ok(f.container.children.length > 72);
  stopSecond();
  assert.equal(f.container.children.length, 0);
  assert.equal(f.timers.size, 0);
});

test('reduced motion creates no moving effects or timers', () => {
  const f = sceneFixture();
  const stop = f.module.play(f.container, { id: 'spring', symbol: 'spring.svg' }, { reduced: true });
  assert.equal(f.container.children.length, 0);
  assert.equal(f.timers.size, 0);
  stop();
});
