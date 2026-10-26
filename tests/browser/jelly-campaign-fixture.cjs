const { createHash } = require('node:crypto');
const words = require('../../words.json');
const entries = require('../../data/vocabulary/morphology/age-03.json').entries;

function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') return `{${Object.keys(value).sort()
    .map(key => `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`;
  // Godot's parsed review JSON retains whole numbers as floats, including schema 1.0.
  if (typeof value === 'number' && Number.isInteger(value)) return `${value}.0`;
  return JSON.stringify(value);
}

function recipe({ seconds = 180, quota = 1 } = {}) {
  const ids = ['cat', 'dog', 'duck'];
  const identities = Object.fromEntries(ids.map(id => {
    const word = words.find(item => item.id === id);
    const entry = entries.find(item => item.id === id);
    const morphology = { ...entry.analysis, review: entry.review };
    const identity = canonical([id, word.text, morphology, Boolean(word.image)]);
    return [id, createHash('sha256').update(identity).digest('hex')];
  }));
  return { version: 1, kind: 'main', number: 1, chapter: 1, title: 'Meadow', profile: 'Discover',
    age: 3, seed: 71, word_ids: ids, identities, goals: Object.fromEntries(ids.map(id => [id, quota])),
    seconds, spawn_interval: 20, fall_speed_scale: 1 };
}

async function seedCampaign(page, { balance = 0, ...options } = {}) {
  const contexts = { growth: { highest_cleared: 0, recipes: { 1: recipe(options) },
    ratings: {}, pending: {}, completed: [] } };
  await page.addInitScript(({ contexts, balance }) => {
    const key = 'growWithPip.jellyCampaign.v1';
    if (localStorage.getItem(key) === null) localStorage.setItem(key,
      `[campaign]\nversion=1\ncontexts=${JSON.stringify(contexts)}\n`);
    const wallet = 'growWithPip.coinWallet.v1';
    if (balance && localStorage.getItem(wallet) === null) localStorage.setItem(wallet,
      `[wallet]\nversion=2\nbalance=${balance}\nreceipts={"campaign-opening-coins":${balance}}\n`);
  }, { contexts, balance });
}

module.exports = { recipe, seedCampaign };
