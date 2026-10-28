'use strict';

(() => {
  const $ = id => document.getElementById(id);
  const categories = { signature: 'Age signatures', inherited: 'Inherited gestures',
    feedback: 'Greetings and answers', attention: 'Idle and attention',
    expressions: 'Expression stills', celebration: 'Shared celebration', loading: 'Loading interactions' };
  const order = [4, 5, 0, 1, 2, 3];
  const media = matchMedia('(prefers-reduced-motion: reduce)');
  const artCache = new Map();
  let catalog, stages, selected, age, art, progress = 0, playing = false, started = 0;
  let request = 0, selection = 0, gridGeneration = 0, visible = [], painted = 0;

  function error(cause) {
    stop();
    $('load-error').hidden = false;
    $('load-error').textContent = cause.message || 'The motion review could not load.';
  }

  async function json(url) {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
    return response.json();
  }

  function stageFor(value) {
    if (catalog.contexts?.[value]) return catalog.contexts[value];
    const stage = stages.stages.find(item => item.age === Number(value));
    if (!stage) throw new Error(`Unknown Pip age: ${value}`);
    return stage;
  }

  function loadArt(stage) {
    if (!artCache.has(stage.age)) artCache.set(stage.age, Promise.all(
      ['regular', 'parts', 'expressions', 'expressionHeads'].filter(key => stage.previewArt[key]).map(async key => {
        const image = new Image();
        image.src = stage.previewArt[key];
        await image.decode();
        if (image.naturalHeight !== (stage.cellSize || 360)) throw new Error(`Invalid production atlas: ${image.src}`);
        return [key, image];
      })
    ).then(entries => ({ ...Object.fromEntries(entries), cellSize: stage.cellSize || 360 })));
    return artCache.get(stage.age);
  }

  function preferredAge(action) {
    const requested = $('age').value;
    const value = action.performances[requested] ? requested : Object.keys(action.performances).at(-1);
    return value === 'loading' ? value : Number(value);
  }

  function draw(canvas, material, frame, size) {
    const dpr = Math.min(2, devicePixelRatio || 1);
    const pixels = Math.round(size * dpr);
    if (canvas.width !== pixels || canvas.height !== pixels) canvas.width = canvas.height = pixels;
    canvas.style.width = canvas.style.height = `${size}px`;
    const context = canvas.getContext('2d');
    context.setTransform(1, 0, 0, 1, 0, 0);
    context.clearRect(0, 0, pixels, pixels);
    const unit = pixels / 120;
    const transform = matrix => context.setTransform(...matrix.map(value => value * unit));
    const cell = (image, index) => context.drawImage(image, index * material.cellSize, 0,
      material.cellSize, material.cellSize, 0, 0, 120, 120);
    if (frame.mode === 'sheet') {
      transform(frame.transform);
      cell(material[frame.sheet], frame.cell);
    } else {
      context.setTransform(unit, 0, 0, unit, 0, 0);
      const [x, y, rx, ry, opacity] = frame.shadow;
      context.fillStyle = `rgba(101,112,138,${opacity})`;
      context.beginPath();
      context.ellipse(x, y, rx, ry, 0, 0, Math.PI * 2);
      context.fill();
      for (const index of order) {
        transform(frame.parts[index]);
        const face = index === 1 && frame.face ? stages.expressions.indexOf(frame.face) : -1;
        if (face >= 0) cell(material.expressionHeads, face);
        else cell(material.parts, index);
      }
    }
    painted++;
  }

  function frameAt(action, variant, value, reduced = false) {
    const performance = action.performances[variant];
    return reduced ? performance.reduced : performance.frames[Math.round(value * (performance.frames.length - 1))];
  }

  function paint() {
    if (!selected || !art) return;
    draw($('pip-player'), art, frameAt(selected, age, progress, $('reduced-motion').checked), Number($('display-size').value));
    $('timeline').value = String(Math.round(progress * 1000));
    const reduced = $('reduced-motion').checked;
    $('timeline').disabled = reduced || Boolean(selected.held);
    $('time').textContent = reduced ? 'Reduced-motion still' : selected.held ? 'Held pose' :
      `${(progress * selected.seconds).toFixed(2)} / ${selected.seconds.toFixed(2)} s`;
  }

  function stop() {
    cancelAnimationFrame(request);
    request = 0;
    playing = false;
    $('play').textContent = $('reduced-motion').checked || selected?.held ? 'Show pose' : 'Play';
    $('play').setAttribute('aria-pressed', 'false');
  }

  function animate(now) {
    request = 0;
    if (!playing || document.hidden) { stop(); return; }
    progress = Math.min(1, (now - started) * Number($('speed').value) / (selected.seconds * 1000));
    paint();
    if (progress === 1) {
      if (!$('loop').checked || selected.held) { stop(); return; }
      progress = 0;
      started = now;
    }
    request = requestAnimationFrame(animate);
  }

  function play(restart = false) {
    if (!selected || !art) return;
    stop();
    if (document.hidden) return;
    if (restart || progress >= 1) progress = 0;
    if ($('reduced-motion').checked || selected.held) { paint(); return; }
    playing = true;
    started = performance.now() - progress * selected.seconds * 1000 / Number($('speed').value);
    $('play').textContent = 'Pause';
    $('play').setAttribute('aria-pressed', 'true');
    request = requestAnimationFrame(animate);
  }

  async function select(action, variant = preferredAge(action)) {
    const token = ++selection;
    stop();
    selected = action;
    age = variant;
    art = null;
    $('motion-player').setAttribute('aria-busy', 'true');
    $('pip-player').hidden = true;
    for (const id of ['play', 'replay', 'character-replay', 'timeline', 'variant-age']) $(id).disabled = true;
    const stage = stageFor(age);
    document.documentElement.style.setProperty('--stage', stage.background);
    document.documentElement.style.setProperty('--accent', stage.accent);
    $('player-age').textContent = `${stage.label} · ${stage.name}`;
    $('action-category').textContent = categories[action.category];
    $('action-title').textContent = action.label;
    $('action-description').textContent = action.description || ({
      inherited: 'A previously earned gesture, retained in this age\'s repertoire.',
      feedback: 'A short character response from the existing greeting or answer lifecycle.',
      attention: 'The current idle, speech or attention state. No voice recording is played here.',
      expressions: 'An existing expression still, not a newly authored animation.',
      celebration: 'The shared three-second leap, two-step and reward presentation. Its final pose is held in the game.'
    })[action.category];
    $('action-source').textContent = `Source: ${action.source} · ${action.id} · ${catalog.fps} fps runtime samples`;
    $('variant-age').replaceChildren(...Object.keys(action.performances).map(value => {
      const option = document.createElement('option');
      option.value = value;
      option.textContent = stageFor(value).label;
      return option;
    }));
    $('variant-age').value = String(age);
    document.querySelectorAll('.motion-card').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.action === action.id)));
    const material = await loadArt(stage);
    if (token !== selection) return false;
    art = material;
    progress = 0.5;
    paint();
    $('pip-player').hidden = false;
    $('pip-player').setAttribute('aria-label', `${action.label}, ${stage.label}`);
    for (const id of ['play', 'replay', 'character-replay', 'variant-age']) $(id).disabled = false;
    $('motion-player').setAttribute('aria-busy', 'false');
    stop();
    return true;
  }

  async function filter() {
    const generation = ++gridGeneration;
    const query = $('search').value.trim().toLowerCase();
    visible = catalog.actions.filter(action =>
      ($('category').value === 'all' || action.category === $('category').value) &&
      ($('age').value === 'all' || action.performances[$('age').value]) &&
      `${action.label} ${action.id} ${action.description || ''}`.toLowerCase().includes(query));
    $('filter-count').textContent = `${visible.length} of ${catalog.actions.length} actions and states`;
    $('empty').hidden = visible.length > 0;
    const cards = visible.map(action => {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'motion-card';
      button.dataset.action = action.id;
      button.setAttribute('aria-pressed', String(selected?.id === action.id));
      const category = document.createElement('span');
      category.className = 'card-category';
      category.textContent = categories[action.category];
      const canvas = document.createElement('canvas');
      canvas.setAttribute('aria-hidden', 'true');
      const label = document.createElement('strong');
      label.textContent = action.label;
      const meta = document.createElement('span');
      meta.className = 'card-meta';
      const variant = preferredAge(action);
      meta.textContent = `${stageFor(variant).label} · ${action.held ? 'held state' : `${action.seconds.toFixed(2)} s`}`;
      button.append(category, canvas, label, meta);
      button.addEventListener('click', () => select(action).then(accepted => {
        if (!accepted) return;
        $('motion-player').scrollIntoView({ block: 'start', behavior: 'auto' });
        play(true);
      }).catch(error));
      loadArt(stageFor(variant)).then(material => {
        if (generation === gridGeneration) draw(canvas, material, frameAt(action, variant, 0.5), 120);
      }).catch(error);
      return button;
    });
    $('action-grid').replaceChildren(...cards);
    if (visible.length && (!visible.includes(selected) || $('age').value !== 'all')) await select(visible[0]);
    else if (!visible.length) stop();
  }

  async function initialize() {
    [catalog, stages] = await Promise.all([json('action-catalog.json'), json('stages.json')]);
    if (catalog.version !== 1 || !Array.isArray(catalog.actions) || !catalog.actions.length)
      throw new Error('Unsupported or empty native action catalog.');
    $('inventory').textContent = `${catalog.actions.length} existing actions and states · ${catalog.performances} performances · ${stages.stages.length} ages + loading`;
    for (const stage of stages.stages) {
      const option = document.createElement('option');
      option.value = String(stage.age);
      option.textContent = stage.label;
      $('age').append(option);
    }
    for (const [value, context] of Object.entries(catalog.contexts || {})) {
      const option = document.createElement('option');
      option.value = value;
      option.textContent = context.label;
      $('age').append(option);
    }
    $('reduced-motion').checked = media.matches;
    $('category').addEventListener('change', () => filter().catch(error));
    $('age').addEventListener('change', () => filter().catch(error));
    $('search').addEventListener('input', () => filter().catch(error));
    $('play').addEventListener('click', () => playing ? stop() : play());
    $('replay').addEventListener('click', () => play(true));
    $('character-replay').addEventListener('click', () => play(true));
    $('variant-age').addEventListener('change', () => {
      const value = $('variant-age').value;
      select(selected, value === 'loading' ? value : Number(value)).catch(error);
    });
    $('display-size').addEventListener('change', paint);
    $('speed').addEventListener('change', () => { if (playing) play(); });
    $('timeline').addEventListener('input', () => { stop(); progress = Number($('timeline').value) / 1000; paint(); });
    $('reduced-motion').addEventListener('change', () => { stop(); paint(); });
    media.addEventListener('change', event => { $('reduced-motion').checked = event.matches; stop(); paint(); });
    document.addEventListener('visibilitychange', () => { if (document.hidden) stop(); });
    window.addEventListener('pagehide', stop);
    document.addEventListener('keydown', event => { if (event.key === 'Escape') stop(); });
    await filter();
    document.body.dataset.ready = 'true';
  }

  window.pipActionsReview = Object.freeze({ snapshot: () => ({
    ready: document.body.dataset.ready === 'true', action: selected?.id, age,
    progress, playing, reducedMotion: $('reduced-motion').checked, painted,
    visible: visible.map(action => action.id), total: catalog?.actions.length
  }) });
  initialize().catch(error);
})();
