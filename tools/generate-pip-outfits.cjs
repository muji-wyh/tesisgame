#!/usr/bin/env node
'use strict';

// Rebuild the complete pose and articulated sheets from the original Pip art
// and the editable body/head designs in outfits/wardrobe.svg.
const fs = require('node:fs');
const path = require('node:path');

const THEMES = ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy'];
const ROOT = path.resolve(__dirname, '..');
const MASCOTS = 'assets/images/mascots';

// These source SVGs use ordinary nested elements and quoted attributes. Keep
// their complete tree so tilted/preening heads retain every original transform.
function parseSvg(source) {
  const document = { tag: '#document', attributes: {}, children: [] };
  const stack = [document];
  const tokens = source.match(/<!--[\s\S]*?-->|<(?:[^>"']|"[^"]*"|'[^']*')*>|[^<]+/g) || [];
  for (const token of tokens) {
    if (token.startsWith('<!--') || token.startsWith('<?')) continue;
    if (token.startsWith('</')) {
      const tag = token.slice(2, -1).trim();
      if (stack.length === 1 || stack.pop().tag !== tag) throw new Error(`Unbalanced SVG element: ${tag}`);
    } else if (token.startsWith('<')) {
      const match = /^<([\w:-]+)([\s\S]*?)(\/?)>$/.exec(token);
      if (!match) throw new Error(`Unsupported SVG markup: ${token}`);
      const node = { tag: match[1], attributes: {}, children: [] };
      let remaining = match[2];
      for (const attribute of match[2].matchAll(/([\w:-]+)\s*=\s*("[^"]*"|'[^']*')/g)) {
        node.attributes[attribute[1]] = attribute[2].slice(1, -1);
        remaining = remaining.replace(attribute[0], '');
      }
      if (remaining.trim()) throw new Error(`Malformed SVG attributes: ${remaining}`);
      stack.at(-1).children.push(node);
      if (!match[3]) stack.push(node);
    } else if (token.trim()) {
      stack.at(-1).children.push(token.trim());
    }
  }
  if (stack.length !== 1 || document.children.length !== 1 || document.children[0].tag !== 'svg') {
    throw new Error('Expected one complete SVG document');
  }
  return document.children[0];
}

function serialize(node, depth = 0) {
  const indent = '  '.repeat(depth);
  if (typeof node === 'string') return indent + node;
  const attributes = Object.entries(node.attributes)
    .map(([name, value]) => ` ${name}="${value.replaceAll('"', '&quot;')}"`).join('');
  if (!node.children.length) return `${indent}<${node.tag}${attributes} />`;
  if (node.children.every(child => typeof child === 'string')) {
    return `${indent}<${node.tag}${attributes}>${node.children.join('')}</${node.tag}>`;
  }
  return `${indent}<${node.tag}${attributes}>\n${node.children.map(child => serialize(child, depth + 1)).join('\n')}\n${indent}</${node.tag}>`;
}

function readSources(root = ROOT) {
  const read = file => fs.readFileSync(path.join(root, MASCOTS, file), 'utf8');
  return { wardrobe: read('outfits/wardrobe.svg'), regular: read('pip.svg'),
    idle: read('pip-idle-actions.svg'), parts: read('pip-dance-parts.svg') };
}

function buildOutfits(sources) {
  const wardrobe = parseSvg(sources.wardrobe);
  const definitions = wardrobe.children.find(child => child.tag === 'defs');
  if (!definitions) throw new Error('The wardrobe source needs editable body/head definitions');
  const layers = new Map(definitions.children.map(node => [node.attributes.id, node]));
  const layer = (theme, part) => {
    const source = layers.get(`${theme}-${part}`);
    if (!source) throw new Error(`Missing ${theme} ${part} wardrobe design`);
    const copy = structuredClone(source);
    delete copy.attributes.id;
    return copy;
  };
  const clearBellyHighlight = node => {
    node.children = node.children.filter(child => child.attributes?.stroke !== '#FFEDA9');
  };
  const result = {};
  for (const theme of THEMES) {
    for (const [kind, suffix, count] of [['regular', '', 4], ['idle', '-idle', 4], ['parts', '-parts', 6]]) {
      const sheet = parseSvg(sources[kind]);
      sheet.children = sheet.children.filter(child => child.tag !== 'title');
      sheet.children.unshift({ tag: 'title', attributes: {}, children: [
        `Pip ${theme} wardrobe${suffix}; derived from wardrobe.svg and the original Pip artwork`
      ] });
      const frames = sheet.children.find(child => child.tag === 'g')?.children;
      if (!frames || frames.length !== count || frames.some(frame => frame.tag !== 'g')) {
        throw new Error(`The ${kind} Pip source must contain ${count} pose or limb groups`);
      }
      if (kind === 'parts') {
        clearBellyHighlight(frames[0]);
        frames[0].children.push(layer(theme, 'body'));
        frames[1].children.push(layer(theme, 'head'));
      } else {
        for (const frame of frames) {
          clearBellyHighlight(frame);
          const bodyIndex = frame.children.findIndex(child => child.attributes?.fill === '#F6D36E');
          if (bodyIndex < 0) throw new Error(`Missing original body in ${kind} pose`);
          frame.children.splice(bodyIndex + 1, 0, layer(theme, 'body'));
          const tiltedHead = frame.children.find(child => child.tag === 'g' &&
            child.children.some(part => part.attributes?.d?.startsWith('M23 39')));
          (tiltedHead || frame).children.push(layer(theme, 'head'));
        }
      }
      result[`pip-${theme}${suffix}.svg`] = serialize(sheet) + '\n';
    }
  }
  return result;
}

function generate(root = ROOT, { check = false } = {}) {
  const output = path.join(root, MASCOTS, 'outfits');
  const sheets = buildOutfits(readSources(root));
  const stale = [];
  for (const [name, svg] of Object.entries(sheets)) {
    const target = path.join(output, name);
    if (check) {
      if (!fs.existsSync(target) || fs.readFileSync(target, 'utf8').replaceAll('\r\n', '\n') !== svg) stale.push(name);
    } else {
      fs.writeFileSync(target, svg);
    }
  }
  if (stale.length) throw new Error(`Regenerate Pip outfits: ${stale.join(', ')}`);
  return Object.keys(sheets).length;
}

if (require.main === module) {
  const check = process.argv.includes('--check');
  console.log(`${check ? 'Verified' : 'Generated'} ${generate(ROOT, { check })} complete Pip wardrobe sheets.`);
}

module.exports = { THEMES, readSources, buildOutfits, generate };
