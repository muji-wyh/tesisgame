const { test, expect } = require('@playwright/test');
const { openGame, metrics, tap, observeAudio, openModeMenu } = require('./game-ui.cjs');
const { expectRecording, recordingTiming } = require('./bundled-audio.cjs');

const wallet = page => page.locator('#coin-status').evaluate(node => JSON.parse(node.dataset.snapshot || '{}'));
const hint = async page => (await metrics(page)).growth.controls.find(control => control.name === 'Hint');
const clip = 'assets/audio/coins/collect.wav';

async function start(page, balance, reducedMotion = 'no-preference') {
  await observeAudio(page, { fingerprintBuffers: true });
  await page.addInitScript(balance => localStorage.setItem('growWithPip.coinWallet.v1',
    `[wallet]\nversion=2\nbalance=${balance}\nreceipts=${JSON.stringify({ 'hint-feedback-funding': balance })}\n`), balance);
  return openGame(page, { reducedMotion });
}

async function pressHint(page) {
  const [x, y, w, h] = (await hint(page)).rect;
  await tap(page, x + w / 2, y + h / 2);
}

async function observeWallet(page) {
  await page.evaluate(() => {
    window.hintWalletFrames = [];
    const node = document.querySelector('#coin-status');
    new MutationObserver(() => window.hintWalletFrames.push(JSON.parse(node.dataset.snapshot || '{}')))
      .observe(node, { attributes: true, attributeFilter: ['data-snapshot'] });
  });
}

test('Hint saved payment rolls coins down with sound and survives its disabled state', async ({ page }, testInfo) => {
  const errors = await start(page, 1000);
  await observeWallet(page);
  const from = await page.evaluate(() => window.audioObservation.playbacks.length);
  await pressHint(page);
  await expect.poll(async () => (await wallet(page)).balance).toBe(900);
  await expectRecording(page, from, clip);
  expect((await hint(page)).disabled).toBe(true);
  await page.screenshot({ path: testInfo.outputPath('hint-paid.png') });
  await expect.poll(async () => (await wallet(page)).displayed).toBe(900);
  const savedPurchase = await page.evaluate(() => localStorage.getItem('growWithPip.coinWallet.v1'));
  expect((await metrics(page)).growth.match.hint).toMatchObject({ uses: 1, price: 150, active: true });
  const frames = await page.evaluate(() => window.hintWalletFrames);
  expect(frames.some(frame => frame.debit_active && frame.debit_amount === 100)).toBe(true);
  expect(frames.some(frame => frame.displayed > 900 && frame.displayed < 1000)).toBe(true);
  await pressHint(page);
  expect((await wallet(page)).balance).toBe(900);
  expect(await page.evaluate(() => localStorage.getItem('growWithPip.coinWallet.v1'))).toBe(savedPurchase);
  expect((await metrics(page)).growth.match.hint.uses).toBe(1);
  const timing = recordingTiming(clip);
  const count = await page.evaluate(({ from, timing }) => window.audioObservation.playbacks.slice(from)
    .filter(sound => Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate).length,
    { from, timing });
  expect(count).toBe(1);
  await openModeMenu(page);
  expect((await wallet(page)).debit_active).toBe(false);
  expect(errors).toEqual([]);
});

test('Hint insufficient funds shakes without spending or coin audio', async ({ page }, testInfo) => {
  const errors = await start(page, 50);
  const savedWallet = await page.evaluate(() => localStorage.getItem('growWithPip.coinWallet.v1'));
  const from = await page.evaluate(() => window.audioObservation.playbacks.length);
  await pressHint(page);
  await expectRecording(page, from, 'assets/imported-audio/pair-feedback/wrong.wav');
  await page.screenshot({ path: testInfo.outputPath('hint-rejected.png') });
  expect(await wallet(page)).toMatchObject({ balance: 50, displayed: 50, debit_active: false });
  const timing = recordingTiming(clip);
  const count = await page.evaluate(({ from, timing }) => window.audioObservation.playbacks.slice(from)
    .filter(sound => Math.abs(sound.duration - timing.seconds) <= timing.importAllowance + 1 / sound.sampleRate).length,
    { from, timing });
  expect(count).toBe(0);
  expect((await metrics(page)).growth.match.hint).toMatchObject({ uses: 0, price: 100, active: false });
  expect(await page.evaluate(() => localStorage.getItem('growWithPip.coinWallet.v1'))).toBe(savedWallet);
  expect(errors).toEqual([]);
});

test('Hint reduced motion keeps the payment amount visible without rolling the balance', async ({ page }, testInfo) => {
  const errors = await start(page, 100, 'reduce');
  await observeWallet(page);
  await pressHint(page);
  await expect.poll(async () => (await wallet(page)).balance).toBe(0);
  expect(await wallet(page)).toMatchObject({ displayed: 0, target: 0 });
  const frames = await page.evaluate(() => window.hintWalletFrames);
  expect(frames.some(frame => frame.debit_active && frame.debit_amount === 100 && frame.displayed === 0)).toBe(true);
  expect(frames.filter(frame => frame.balance === 0).every(frame => frame.displayed === 0)).toBe(true);
  await page.screenshot({ path: testInfo.outputPath('hint-reduced.png') });
  expect(errors).toEqual([]);
});
