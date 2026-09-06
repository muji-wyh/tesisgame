const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');

const root = path.join(__dirname, '..');

function loadInline(id, globals = {}) {
  const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  const match = html.match(new RegExp(`<script id="${id}">([\\s\\S]*?)<\\/script>`));
  assert.ok(match, `Missing inline script: ${id}`);
  const context = vm.createContext({ ...globals });
  new vm.Script(match[1], { filename: `index.html#${id}` }).runInContext(context);
  return context;
}

function loadWords() {
  return JSON.parse(fs.readFileSync(path.join(root, 'words.json'), 'utf8'));
}

module.exports = { loadInline, loadWords, root };
