const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { root } = require('.\\load-inline.cjs');

test('runtime interface is English and uses prerecorded rather than browser-generated speech', () => {
  const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  assert.match(html, /<html lang="en">/);
  assert.doesNotMatch(html, /\p{Script=Han}/u);
  assert.doesNotMatch(html, /speechSynthesis|SpeechSynthesisUtterance/);
});

test('responsive layout keeps zoom enabled and includes safe areas and reduced motion', () => {
  const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  assert.match(html, /viewport-fit=cover/);
  assert.match(html, /100dvh/);
  assert.match(html, /safe-area-inset-bottom/);
  assert.match(html, /prefers-reduced-motion/);
  assert.doesNotMatch(html, /user-scalable\s*=\s*no|maximum-scale\s*=\s*1/);
});
