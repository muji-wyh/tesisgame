const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const { enterGame, chooseMode, rendered, metrics, visibleColorCount } = require('./game-ui.cjs');

async function installRecognition(page, prefixed) {
  await page.addInitScript(({ prefixed }) => {
    const fixture = { instances: [], starts: 0, aborts: 0, spoken: [], cancellations: 0 };
    class Recognition {
      constructor() {
        this.results = [];
        this.running = false;
        this.onaudiostart = null;
        fixture.instances.push(this);
      }
      start() {
        this.running = true;
        fixture.starts++;
        this.callbacks = { start: this.onstart, audio: this.onaudiostart, result: this.onresult,
          error: this.onerror, end: this.onend };
        queueMicrotask(() => { this.callbacks.start?.(); this.callbacks.audio?.(); });
      }
      abort() {
        this.running = false;
        fixture.aborts++;
        const callbacks = this.callbacks;
        queueMicrotask(() => { callbacks.error?.({ error: 'aborted' }); callbacks.end?.(); });
      }
      stop() { this.abort(); }
      revise(index, text, final = true) {
        this.results[index] = Object.assign([{ transcript: text, confidence: 0.95 }], { isFinal: final });
        this.callbacks.result?.({ resultIndex: index, results: this.results });
      }
      emit(text, final = true) {
        const index = this.results.length && !this.results.at(-1).isFinal ? this.results.length - 1 : this.results.length;
        this.revise(index, text, final);
      }
    }
    window.__questSpeech = fixture;
    Object.defineProperty(window, 'SpeechRecognition', { configurable: true, value: prefixed ? undefined : Recognition });
    Object.defineProperty(window, 'webkitSpeechRecognition', { configurable: true, value: prefixed ? Recognition : undefined });
    Object.defineProperty(window, 'SpeechSynthesisUtterance', { configurable: true,
      value: class { constructor(text) { this.text = text; } } });
    Object.defineProperty(window, 'speechSynthesis', { configurable: true, value: {
      speak(utterance) { fixture.spoken.push(utterance); },
      cancel() { fixture.cancellations++; }
    } });
    if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = async () => {
      throw new Error('Talk Quest browser checks must not open a physical microphone');
    };
  }, { prefixed });
}

function recordErrors(page) {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (/SCRIPT ERROR|Parse Error/.test(message.text())) errors.push(message.text()); });
  return errors;
}

async function snapshot(page) {
  return page.evaluate(() => JSON.parse(document.getElementById('quest-status')?.dataset.snapshot || '{}'));
}

async function waitState(page, expected) {
  let current;
  try {
    await expect.poll(async () => {
      current = await snapshot(page);
      return Object.fromEntries(Object.keys(expected).map(key => [key, current[key]]));
    }, { intervals: [50, 100, 200], timeout: 10000 }).toEqual(expected);
    return current;
  } catch (error) {
    const current = await snapshot(page).catch(() => ({}));
    const observed = Object.fromEntries(Object.keys(expected).map(key => [key, current[key]]));
    throw new Error(`Quest state did not settle. Expected ${JSON.stringify(expected)}; observed ${JSON.stringify(observed)}`, { cause: error });
  }
}

async function waitPrompt(page, level, index, listening = true) {
  return waitState(page, { active: true, view: 'stage', phase: 'playing', level,
    line_index: index, busy: false, listening });
}

async function tapRect(page, rect, name) {
  expect(rect.visible, `${name} is visible in the actual native interface`).toBe(true);
  expect(rect.disabled, `${name} is enabled`).toBe(false);
  const canvas = await page.locator('#canvas').boundingBox();
  expect(canvas).toBeTruthy();
  const x = rect.x + rect.width / 2, y = rect.y + rect.height / 2;
  expect(x, `${name} has an on-screen horizontal center`).toBeGreaterThan(0);
  expect(x).toBeLessThan(1);
  expect(y, `${name} has an on-screen vertical center`).toBeGreaterThan(0);
  expect(y).toBeLessThan(1);
  await page.touchscreen.tap(canvas.x + x * canvas.width, canvas.y + y * canvas.height);
}

async function revealQuestRect(page, select, name) {
  for (let attempt = 0; attempt < 24; attempt++) {
    const current = await snapshot(page), rect = select(current);
    expect(rect?.visible, `${name} exists in the visible native interface`).toBe(true);
    const area = current.controls.stage_scroll;
    if (current.view !== 'stage' || !area?.visible) return rect;
    const bottom = Math.min(1, area.y + area.height);
    if (rect.y >= area.y - 0.002 && rect.y + rect.height <= bottom + 0.002) return rect;
    const canvas = await page.locator('#canvas').boundingBox();
    await page.mouse.move(canvas.x + (area.x + area.width * 0.5) * canvas.width,
      canvas.y + (area.y + area.height * 0.5) * canvas.height);
    const distance = rect.y + rect.height > bottom
      ? (rect.y + rect.height - bottom) * canvas.height + 8 : (rect.y - area.y) * canvas.height - 8;
    if (test.info().project.use.browserName === 'webkit' && test.info().project.use.isMobile) {
      // Playwright mobile WebKit cannot send wheel events. Drag the visible
      // native scrollbar instead; the game still owns its scrolling state.
      const scale = (await metrics(page)).scale;
      const height = area.height * canvas.height;
      const maximum = current.scroll_max * scale;
      const thumb = Math.max(10, height * height / (height + maximum));
      const travel = height - thumb;
      const offset = current.scroll_offset * scale;
      const target = Math.max(0, Math.min(maximum, offset + distance));
      // At this scale the scrollbar is only about four CSS pixels wide.
      const x = canvas.x + (area.x + area.width) * canvas.width - 1;
      const top = canvas.y + area.y * canvas.height + thumb / 2;
      await page.mouse.move(x, top + offset / maximum * travel);
      await page.mouse.down();
      try { await page.mouse.move(x, top + target / maximum * travel, { steps: 6 }); }
      finally { await page.mouse.up(); }
    } else {
      await page.mouse.wheel(0, Math.sign(distance) * Math.min(160, Math.max(24, Math.abs(distance))));
    }
    // Native geometry is republished every 200 ms. Read the real input result.
    await page.waitForTimeout(220);
  }
  throw new Error(`${name} could not be reached by native scrolling: ${JSON.stringify(await snapshot(page))}`);
}

async function visibleQuestControl(page, name) {
  const rect = await revealQuestRect(page, state => state.controls[name], name);
  const current = await snapshot(page), area = current.controls.stage_scroll;
  expect(rect.x, `${name} stays inside the left edge`).toBeGreaterThanOrEqual(-0.002);
  expect(rect.x + rect.width, `${name} stays inside the right edge`).toBeLessThanOrEqual(1.002);
  if (current.view === 'stage' && area?.visible) {
    expect(rect.y, `${name} is not clipped above its scroll viewport`).toBeGreaterThanOrEqual(area.y - 0.002);
    expect(rect.y + rect.height, `${name} is not clipped below its scroll viewport`)
      .toBeLessThanOrEqual(Math.min(1, area.y + area.height) + 0.002);
  }
  return rect;
}

async function clickControl(page, name) {
  await expect.poll(async () => {
    const control = (await snapshot(page)).controls?.[name];
    return Boolean(control?.visible && !control.disabled && control.width > 0 && control.height > 0);
  }, { intervals: [50, 100, 200], timeout: 10000 }).toBe(true);
  await tapRect(page, await visibleQuestControl(page, name), name);
}

async function emit(page, text, final = true) {
  return page.evaluate(({ text, final }) => {
    const fixture = window.__questSpeech, recognition = fixture.instances.at(-1);
    if (!recognition?.running) throw new Error('A real Speak gesture must start capture before delivering browser results');
    recognition.emit(text, final);
    return fixture.instances.length - 1;
  }, { text, final });
}

async function progress(page) {
  return page.evaluate(() => JSON.parse(window.wordBuddiesHost.questProgress()));
}

async function chooseRepairPart(page, index, verifyWrong = false) {
  const expectedParts = ['wheel', 'wing', 'ribbon', 'screw', 'key'];
  const part = expectedParts[Math.floor(index / 4)];
  let current = await waitState(page, { level: 14, phase: 'playing', line_index: index,
    part_required: true, busy: false });
  expect(current).toMatchObject({ hp: 0, max_hp: 0, repairs: Math.floor(index / 4), listening: false });
  expect(current.part_choices).toHaveLength(3);
  expect(current.part_choices.every(choice => choice.id && choice.label)).toBe(true);
  if (verifyWrong) {
    const wrong = current.part_choices.find(choice => choice.id !== part);
    const wrongRect = await revealQuestRect(page,
      state => state.part_choices.find(choice => choice.id === wrong.id).rect, `Incorrect part: ${wrong.label}`);
    await tapRect(page, wrongRect, `Incorrect part: ${wrong.label}`);
    await expect.poll(async () => (await snapshot(page)).feedback, { intervals: [50] }).toContain('Try another shape');
    current = await snapshot(page);
    expect(current).toMatchObject({ line_index: index, hp: 0, repairs: Math.floor(index / 4), part_required: true });
  }
  const correct = current.part_choices.find(choice => choice.id === part);
  expect(correct, `The real part choices include ${part}`).toBeTruthy();
  const correctRect = await revealQuestRect(page,
    state => state.part_choices.find(choice => choice.id === part).rect, `Correct part: ${correct.label}`);
  await tapRect(page, correctRect, `Correct part: ${correct.label}`);
  current = await waitState(page, { level: 14, line_index: index, part_required: false });
  expect(current).toMatchObject({ hp: 0, repairs: Math.floor(index / 4), listening: false });
  expect((await progress(page)).run.selected_parts).toEqual(expectedParts.slice(0, Math.floor(index / 4) + 1));
  return current;
}

function expectPrivateProgress(saved) {
  expect(Object.keys(saved).sort()).toEqual(['completion_counts', 'run', 'version']);
  expect(saved.version).toBe(1);
  expect(saved.completion_counts).toHaveLength(14);
  const allowed = ['clear_number', 'level_number', 'line_index', 'phase', 'run_id', 'selected_parts'];
  expect(Object.keys(saved.run).every(key => allowed.includes(key))).toBe(true);
  expect(JSON.stringify(saved)).not.toMatch(/transcript|event_id|recording|audio|feedback/);
}

async function openQuest(page, browserName) {
  await installRecognition(page, browserName === 'webkit');
  await page.goto('/');
  await enterGame(page);
  await chooseMode(page, 'quest');
  return waitState(page, { active: true, view: 'map' });
}

test('Talk Quest completes all fourteen adventures through browser speech and restores saved progress', async ({ page, browserName }, info) => {
  test.setTimeout(900000);
  const errors = recordErrors(page);
  const map = await openQuest(page, browserName);
  expect(map.completed).toEqual([]);
  expect(map.unlocked).toBe(1);
  expect(map.levels).toHaveLength(14);
  expect(map.levels.map(level => level.disabled)).toEqual([false, ...Array(13).fill(true)]);
  expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(0);
  await tapRect(page, map.levels[0], 'First adventure');
  let current = await waitPrompt(page, 1, 0, false);
  expect(current.prompt).toMatchObject({ speaker: 'Adam', text: 'Knock, knock.', total_lines: 6 });
  expect(current.hp).toBe(60);
  await clickControl(page, 'speak');
  current = await waitPrompt(page, 1, 0);

  const firstRecognition = await emit(page, current.prompt.text, false);
  await expect.poll(async () => (await snapshot(page)).transcript, { intervals: [50] }).toContain('Heard (listening)');
  expect(await snapshot(page)).toMatchObject({ level: 1, line_index: 0, hp: 60 });
  await emit(page, 'Knock, knock. Do not come in.');
  await expect.poll(async () => (await snapshot(page)).feedback, { intervals: [50] }).toContain('whole sentence');
  expect(await snapshot(page)).toMatchObject({ line_index: 0, hp: 60 });
  await page.evaluate(({ index, text }) => window.__questSpeech.instances[index].revise(0, text),
    { index: firstRecognition, text: current.prompt.text });
  await page.waitForTimeout(250);
  expect(await snapshot(page), 'Correcting an already-final wrong occurrence cannot score').toMatchObject({ line_index: 0, hp: 60 });
  await emit(page, current.prompt.text);
  current = await waitPrompt(page, 1, 1);
  expect(current.hp).toBe(50);
  await page.evaluate(({ index, text }) => window.__questSpeech.instances[index].revise(2, text),
    { index: firstRecognition, text: current.prompt.text });
  await page.waitForTimeout(250);
  expect(await snapshot(page), 'A late callback from the previous turn cannot score the next sentence')
    .toMatchObject({ line_index: 1, hp: 50 });

  const completedEvidence = [];
  let restoredMidSentence = false;
  for (let level = 1; level <= 14; level++) {
    if (level > 1) {
      current = await waitPrompt(page, level, 0, false);
      expect(await page.evaluate(() => window.__questSpeech.instances.some(instance => instance.running))).toBe(false);
      if (level === 14) {
        await page.screenshot({ path: info.outputPath('talk-quest-workshop-parts.png') });
        current = await chooseRepairPart(page, 0, true);
      }
      await clickControl(page, 'speak');
      current = await waitPrompt(page, level, 0);
    }
    const lineCount = current.prompt.total_lines;
    if ([1, 8, 13].includes(level)) {
      await page.screenshot({ path: info.outputPath(`talk-quest-level-${level}.png`) });
    }
    expect(lineCount).toBeGreaterThanOrEqual(6);
    expect(current.max_hp).toBe(level === 14 ? 0 : lineCount * 10);
    if (level === 14) {
      expect(current).toMatchObject({ hp: 0, max_hp: 0, repairs: 0 });
      await page.screenshot({ path: info.outputPath('talk-quest-workshop-start.png') });
    }
    while (current.line_index < lineCount) {
      if (level === 14 && current.line_index > 0 && current.line_index % 4 === 0) {
        current = await chooseRepairPart(page, current.line_index);
        await clickControl(page, 'speak');
      }
      current = await waitPrompt(page, level, current.line_index);
      if (level === 2 && current.line_index === 2 && !restoredMidSentence) {
        const checkpoint = { level: current.level, line_index: current.line_index, hp: current.hp,
          prompt: current.prompt, completed: current.completed, chests: current.chests };
        const saved = await progress(page);
        expectPrivateProgress(saved);
        expect(saved.run).toMatchObject({ level_number: 2, line_index: 2, phase: 'playing' });
        await page.reload();
        await enterGame(page);
        await chooseMode(page, 'quest');
        const restoredMap = await waitState(page, { active: true, view: 'map' });
        expect(restoredMap.controls.continue.visible).toBe(true);
        expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(0);
        await clickControl(page, 'continue');
        current = await waitPrompt(page, 2, 2, false);
        expect(current).toMatchObject(checkpoint);
        expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(0);
        await clickControl(page, 'speak');
        current = await waitPrompt(page, 2, 2);
        restoredMidSentence = true;
      }
      const before = current;
      await emit(page, before.prompt.text);
      current = await waitState(page, { level, line_index: before.line_index + 1 });
      expect(current.save_failed).toBe(false);
      if (level === 14) {
        expect(current.hp).toBe(0);
        expect(current.max_hp).toBe(0);
        expect(current.repairs).toBe(Math.floor(current.line_index / 4));
      } else {
        expect(current.hp, 'Each accepted whole sentence removes exactly ten HP').toBe(before.hp - 10);
      }
    }
    expect(current.phase).toBe('victory');
    expect(current.completed).toHaveLength(level - 1);
    expect(current.total_clears).toBe(level - 1);
    if (level === 14) expect(current.repairs).toBe(5);
    current = await waitState(page, { level, phase: 'chest', busy: false });
    expect(current.completed).toHaveLength(level - 1);
    await clickControl(page, 'open');
    await waitState(page, { level, phase: 'chest', busy: true });
    if (level === 1) {
      await page.waitForTimeout(750);
      expect(await snapshot(page), 'The real chest presentation does not award treasure immediately')
        .toMatchObject({ phase: 'chest', completed: [], total_clears: 0 });
    }
    current = await waitState(page, { level, phase: 'complete' });
    expect(current.completed).toEqual(Array.from({ length: level }, (_, index) => index + 1));
    expect(current.unlocked).toBe(Math.min(14, level + 1));
    expect(current.total_clears).toBe(level);
    expect(current.chests).toHaveLength(level);
    expect(current.controls.next.disabled, 'The next adventure waits for the chest presentation to finish').toBe(true);
    expectPrivateProgress(await progress(page));
    completedEvidence.push({ level, lineCount, hp: current.hp, repairs: current.repairs,
      completed: current.completed, chests: current.chests });
    await clickControl(page, 'next');
  }

  expect(restoredMidSentence).toBe(true);
  const finished = await waitState(page, { active: true, view: 'map', total_clears: 14 });
  expect(finished.completed).toEqual(Array.from({ length: 14 }, (_, index) => index + 1));
  expect(finished.chests).toEqual(Array.from({ length: 14 }, (_, index) => `chest-${String(index + 1).padStart(2, '0')}`));
  expect(finished.levels.every(level => !level.disabled)).toBe(true);
  const saved = await progress(page);
  expectPrivateProgress(saved);
  expect(saved.completion_counts).toEqual(Array(14).fill(1));
  expect(saved.run).toEqual({});
  await clickControl(page, 'album');
  await waitState(page, { view: 'album' });
  await page.screenshot({ path: info.outputPath('talk-quest-treasure-shelf.png') });
  await page.reload();
  await enterGame(page);
  await chooseMode(page, 'quest');
  const reloaded = await waitState(page, { active: true, view: 'map', total_clears: 14 });
  expect(reloaded.completed).toEqual(finished.completed);
  expect(reloaded.chests).toEqual(finished.chests);
  expect(reloaded.unlocked).toBe(14);
  expect(reloaded.controls.continue.visible).toBe(false);
  expect(await progress(page)).toEqual(saved);
  expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(0);
  expect(errors).toEqual([]);
  await info.attach('talk-quest-completion-evidence', { body: JSON.stringify({ completedEvidence, saved }, null, 2),
    contentType: 'application/json' });
});

test('Hear line and leaving an adventure stop capture without scoring or reopening the microphone', async ({ page, browserName }, info) => {
  const errors = recordErrors(page);
  const map = await openQuest(page, browserName);
  await tapRect(page, map.levels[0], 'First adventure');
  const first = await waitPrompt(page, 1, 0, false);
  await clickControl(page, 'speak');
  await waitPrompt(page, 1, 0);
  await clickControl(page, 'hear');
  await waitPrompt(page, 1, 0, false);
  await expect.poll(() => page.evaluate(() => window.__questSpeech.spoken.length), { intervals: [50] }).toBe(1);
  expect(await page.evaluate(() => ({ text: window.__questSpeech.spoken[0].text,
    lang: window.__questSpeech.spoken[0].lang, rate: window.__questSpeech.spoken[0].rate,
    running: window.__questSpeech.instances.some(instance => instance.running) })))
    .toEqual({ text: first.prompt.text, lang: 'en-US', rate: 0.85, running: false });
  await page.evaluate(text => {
    window.__questSpeech.instances[0].emit(text);
    window.__questSpeech.spoken[0].onend?.();
  }, first.prompt.text);
  await rendered(page);
  expect(await snapshot(page)).toMatchObject({ hp: first.hp, line_index: 0, listening: false });
  expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(1);
  await page.screenshot({ path: info.outputPath('talk-quest-first-adventure.png') });
  await clickControl(page, 'speak');
  await waitPrompt(page, 1, 0);
  await clickControl(page, 'map');
  await waitState(page, { view: 'map', listening: false });
  await page.evaluate(text => window.__questSpeech.instances.at(-1).emit(text), first.prompt.text);
  await rendered(page);
  expect(await snapshot(page)).toMatchObject({ hp: first.hp, line_index: 0, total_clears: 0 });
  expect(await page.evaluate(() => window.__questSpeech.instances.some(instance => instance.running))).toBe(false);
  await clickControl(page, 'continue');
  await waitPrompt(page, 1, 0, false);
  expect(await page.evaluate(() => window.__questSpeech.starts)).toBe(2);
  await clickControl(page, 'speak');
  await waitPrompt(page, 1, 0);
  await chooseMode(page, 'match');
  await waitState(page, { active: false, listening: false });
  await page.evaluate(text => window.__questSpeech.instances.at(-1).emit(text), first.prompt.text);
  await rendered(page);
  expect(await snapshot(page)).toMatchObject({ hp: first.hp, line_index: 0, total_clears: 0 });
  expect(await page.evaluate(() => window.__questSpeech.instances.some(instance => instance.running))).toBe(false);
  expectPrivateProgress(await progress(page));
  expect(errors).toEqual([]);
});

test('typing works without browser speech at phone sizes and a backgrounded chest keeps its one reward', async ({ page }, info) => {
  test.setTimeout(150000);
  const errors = recordErrors(page);
  await page.setViewportSize({ width: 320, height: 568 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.addInitScript(() => {
    window.__questNoSpeech = { microphoneRequests: 0 };
    Object.defineProperty(window, 'SpeechRecognition', { configurable: true, value: undefined });
    Object.defineProperty(window, 'webkitSpeechRecognition', { configurable: true, value: undefined });
    if (navigator.mediaDevices) navigator.mediaDevices.getUserMedia = async () => {
      window.__questNoSpeech.microphoneRequests++;
      throw new Error('The typed fallback must not request a microphone');
    };
  });
  const response = await page.goto('/');
  expect(await response.text(), 'The actual export enables the mobile text-entry bridge')
    .toMatch(/"experimentalVK"\s*:\s*true/);
  await enterGame(page);
  await chooseMode(page, 'quest');
  const map = await waitState(page, { active: true, view: 'map' });
  await tapRect(page, map.levels[0], 'First adventure');
  let current = await waitPrompt(page, 1, 0, false);
  expect(current.reduced_motion).toBe(true);
  expect(current.controls.speak.disabled).toBe(true);
  expect(current.controls.type.disabled).toBe(false);
  expect(await page.evaluate(() => window.wordBuddiesHost.speechAvailable())).toBe(false);

  const layouts = [];
  async function inspectPrompt(label) {
    const rect = await visibleQuestControl(page, 'prompt');
    const canvas = await page.locator('#canvas').boundingBox();
    const value = await snapshot(page);
    expect(value.prompt.text.length).toBeGreaterThan(0);
    expect(rect.width * canvas.width, 'The complete sentence has readable horizontal space').toBeGreaterThan(100);
    expect(rect.height * canvas.height, 'The rendered sentence is not collapsed').toBeGreaterThan(30);
    expect(value.reduced_motion).toBe(true);
    const png = await page.screenshot({ path: info.outputPath(`talk-quest-typing-${label}.png`) });
    const raw = await page.locator('#canvas').evaluate(canvas => new Promise(resolve =>
      requestAnimationFrame(() => resolve(canvas.toDataURL('image/png').split(',')[1]))));
    const canvasPng = Buffer.from(raw, 'base64');
    fs.writeFileSync(info.outputPath(`talk-quest-typing-${label}-canvas.png`), canvasPng);
    const pageColors = await visibleColorCount(page, png), canvasColors = await visibleColorCount(page, canvasPng);
    expect(canvasColors, `${label}: the game continues drawing after a resize`).toBeGreaterThan(20);
    if (label !== 'portrait' && pageColors === 1 && process.platform === 'win32' &&
        info.project.use.browserName === 'webkit') {
      info.annotations.push({ type: 'rendering-limitation',
        description: `${label}: existing Windows WebKit presentation/capture limitation after resize; the page PNG is blank while the raw canvas renders. Both retained.` });
    } else {
      expect(pageColors, `${label}: the page shows the rendered game`).toBeGreaterThan(20);
    }
    layouts.push({ label, viewport: page.viewportSize(), prompt: value.prompt, rect,
      scroll_offset: value.scroll_offset, scroll_max: value.scroll_max, pageColors, canvasColors });
  }
  async function typeLine(text, submitWithEnter = false) {
    if (!(await snapshot(page)).controls.input.visible) await clickControl(page, 'type');
    await clickControl(page, 'input');
    const editor = page.locator('input:focus, textarea:focus');
    await expect(editor, 'Touching the real LineEdit focuses the exported native text-entry bridge').toHaveCount(1);
    await expect(editor).toBeEditable();
    await expect(editor).toBeVisible();
    await editor.fill(text);
    await expect(editor).toHaveValue(text);
    await rendered(page);
    if (submitWithEnter) await page.keyboard.press('Enter');
    else await clickControl(page, 'submit');
  }

  await inspectPrompt('portrait');
  await typeLine('Knock, knock. Do not come in.');
  await expect.poll(async () => (await snapshot(page)).feedback, { intervals: [50] }).toContain('whole sentence');
  expect(await snapshot(page), 'A typed mismatch has the same whole-sentence rule as speech')
    .toMatchObject({ line_index: 0, hp: 60, total_clears: 0, listening: false });
  await visibleQuestControl(page, 'feedback');
  await typeLine(current.prompt.text);
  current = await waitPrompt(page, 1, 1, false);
  expect(current.hp).toBe(50);

  await page.setViewportSize({ width: 568, height: 320 });
  await rendered(page);
  await page.waitForTimeout(250);
  current = await waitPrompt(page, 1, 1, false);
  expect(current.scroll_max, 'The landscape view keeps overflowing native content scrollable').toBeGreaterThan(0);
  await inspectPrompt('landscape');
  // A normal keyboard Enter reaches LineEdit.text_submitted through the same
  // focused DOM editor used by a phone software keyboard.
  await typeLine('WHO IS THAT?', true);
  current = await waitPrompt(page, 1, 2, false);
  expect(current.hp).toBe(40);
  expect(current.prompt.text).toBe("It's me, Adam.");

  await page.setViewportSize({ width: 320, height: 568 });
  await rendered(page);
  await page.waitForTimeout(250);
  await inspectPrompt('portrait-return');
  while (current.phase === 'playing') {
    const before = await waitPrompt(page, 1, current.line_index, false);
    await visibleQuestControl(page, 'prompt');
    await typeLine(before.prompt.text, before.line_index % 2 === 0);
    current = await waitState(page, { level: 1, line_index: before.line_index + 1 });
    expect(current.hp).toBe(before.hp - 10);
    expect(current.listening).toBe(false);
  }
  expect(current.phase).toBe('victory');
  expect(current.completed).toEqual([]);
  await waitState(page, { level: 1, phase: 'chest', busy: false });
  await clickControl(page, 'open');
  current = await waitState(page, { level: 1, phase: 'complete', busy: true });
  expect(current.controls.next.disabled).toBe(true);
  expect(current).toMatchObject({ completed: [1], total_clears: 1, chests: ['chest-01'] });
  const awarded = await progress(page);
  expectPrivateProgress(awarded);

  try {
    // Simulate only the browser lifecycle, as the existing browser suite does.
    // The native quest receives its normal host callback and owns all pausing.
    await page.evaluate(() => {
      Object.defineProperty(document, 'hidden', { configurable: true, value: true });
      document.dispatchEvent(new Event('visibilitychange'));
    });
    await expect.poll(async () => {
      const value = await snapshot(page);
      return value.controls.resume.visible && !value.controls.next.visible;
    }, { intervals: [50, 100, 200], timeout: 10000 }).toBe(true);
    await page.waitForTimeout(1900);
    expect(await snapshot(page), 'The paused opening tail cannot award the same chest again')
      .toMatchObject({ phase: 'complete', completed: [1], total_clears: 1, chests: ['chest-01'] });
    expect(await progress(page)).toEqual(awarded);
  } finally {
    await page.evaluate(() => {
      delete document.hidden;
      document.dispatchEvent(new Event('visibilitychange'));
    });
  }
  expect((await snapshot(page)).controls.resume.visible).toBe(true);
  await clickControl(page, 'resume');
  current = await waitState(page, { phase: 'complete', busy: false, total_clears: 1 });
  expect(current.controls.next.disabled).toBe(false);
  expect(current.controls.resume.visible).toBe(false);
  expect(await progress(page)).toEqual(awarded);
  await clickControl(page, 'next');
  current = await waitPrompt(page, 2, 0, false);
  expect(current.completed).toEqual([1]);
  expect(current.controls.speak.disabled).toBe(true);
  await inspectPrompt('next-adventure');
  expect(await page.evaluate(() => window.__questNoSpeech.microphoneRequests)).toBe(0);
  expect(errors).toEqual([]);
  await info.attach('talk-quest-typing-layouts', { body: JSON.stringify({ layouts, awarded }, null, 2),
    contentType: 'application/json' });
});
