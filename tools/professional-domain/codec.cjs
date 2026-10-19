'use strict';
// Bounded build-time JSON contract. Application authority comes from audited packaging and its embedded pin.
const crypto = require('node:crypto');
const fs = require('node:fs');
const LIMITS = Object.freeze({file: 8 * 1024 * 1024, inputTotal: 48 * 1024 * 1024,
  files: 1024, traversalEntries: 4096, traversalDepth: 8, decisionManifest: 512 * 1024,
  depth: 64, nodes: 1000000, array: 20000, keys: 512, string: 262144,
  courses: 64, modulesPerCourse: 32, modules: 1024, lexemes: 12000, expressions: 6000,
  sources: 4000, selectedLexemes: 128, selectedExpressions: 64, decisions: 128,
  coldBytes: 2 * 1024 * 1024, coldOpens: 16, rootIndex: 256 * 1024,
  payload: 512 * 1024, view: 128 * 1024, scope: 256 * 1024,
  scopeTotal: 1536 * 1024, pack: 1792 * 1024, members: 1024, header: 128 * 1024});
const sha256 = input => crypto.createHash('sha256').update(input).digest('hex');
function readBounded(filename,maximum) {
  if (!Number.isSafeInteger(maximum) || maximum < 1 || maximum > LIMITS.inputTotal) throw Error('Invalid bounded read limit');
  const initial = fs.lstatSync(filename);
  if (!initial.isFile() || initial.isSymbolicLink()) throw Error('Bounded read requires a regular non-symlink file');
  const fd = fs.openSync(filename,'r');
  try {
    const stat = fs.fstatSync(fd);
    if (!stat.isFile() || stat.size > maximum || stat.size !== initial.size) throw Error('File byte budget exceeded or file changed before read');
    const buffer = Buffer.alloc(stat.size + 1); let used = 0;
    while (used < buffer.length) {
      const count = fs.readSync(fd,buffer,used,buffer.length-used,null);
      if (!count) break; used += count;
    }
    if (used !== stat.size || fs.fstatSync(fd).size !== stat.size) throw Error('File changed during bounded read');
    return buffer.subarray(0,used);
  } finally { fs.closeSync(fd); }
}
function scalar(value, key = false) {
  if (value.length > LIMITS.string || value.includes('\0')) throw Error('Invalid string size or NUL');
  if (key && !/^[\x20-\x7e]*$/.test(value)) throw Error('Object key must be printable ASCII');
  for (let i = 0; i < value.length; i++) {
    const c = value.charCodeAt(i);
    if (c >= 0xd800 && c <= 0xdbff) {
      const next = value.charCodeAt(++i);
      if (!(next >= 0xdc00 && next <= 0xdfff)) throw Error('Unpaired Unicode surrogate');
    } else if (c >= 0xdc00 && c <= 0xdfff) throw Error('Unpaired Unicode surrogate');
  }
  return value;
}
function canonical(value, depth = 0) {
  if (depth > LIMITS.depth) throw Error('Depth budget exceeded');
  if (value === null || typeof value === 'boolean') return JSON.stringify(value);
  if (typeof value === 'number') {
    if (!Number.isSafeInteger(value)) throw Error('Safe integer required');
    return String(value === 0 ? 0 : value);
  }
  if (typeof value === 'string') return JSON.stringify(scalar(value));
  if (Array.isArray(value)) {
    if (value.length > LIMITS.array) throw Error('Array count budget exceeded');
    return '[' + value.map(x => canonical(x, depth + 1)).join(',') + ']';
  }
  if (value && Object.getPrototypeOf(value) === Object.prototype) {
    const keys = Object.keys(value).sort();
    if (keys.length > LIMITS.keys) throw Error('Object key count budget exceeded');
    return '{' + keys.map(k => JSON.stringify(scalar(k, true)) + ':' + canonical(value[k], depth + 1)).join(',') + '}';
  }
  throw Error('Unsupported canonical type');
}
const encode = value => Buffer.from(canonical(value), 'utf8');
const digest = value => sha256(encode(value));
function strictParse(input, options = {}) {
  const cap = {...LIMITS, ...options};
  const raw = Buffer.isBuffer(input) ? input : Buffer.from(input, 'utf8');
  if (raw.length > cap.file) throw Error('JSON byte budget exceeded');
  let text;
  try { text = new TextDecoder('utf-8', {fatal: true, ignoreBOM: true}).decode(raw); }
  catch { throw Error('Malformed UTF-8'); }
  let at = 0, nodes = 0;
  const error = msg => { throw Error(msg + ' at JSON offset ' + at); };
  const ws = () => { while (/[\x20\t\r\n]/.test(text[at] || '\0')) at++; };
  function string(isKey = false) {
    if (text[at++] !== '"') error('Expected string');
    let result = '';
    while (at < text.length) {
      let c = text[at++];
      if (c === '"') {
        if (result.length > cap.string) error('String budget exceeded');
        return scalar(result, isKey);
      }
      if (c < ' ') error('Unescaped control character');
      if (c === '\\') {
        c = text[at++];
        if (c === 'u') {
          const hex = text.slice(at, at + 4);
          if (!/^[0-9a-fA-F]{4}$/.test(hex)) error('Malformed Unicode escape');
          result += String.fromCharCode(parseInt(hex, 16)); at += 4;
        } else {
          const escapes = {'"': '"', '\\': '\\', '/': '/', b: '\b', f: '\f', n: '\n', r: '\r', t: '\t'};
          if (!Object.hasOwn(escapes, c)) error('Malformed string escape');
          result += escapes[c];
        }
      } else result += c;
      if (result.length > cap.string) error('String budget exceeded');
    }
    error('Unterminated string');
  }
  function value(depth) {
    if (depth > cap.depth || ++nodes > cap.nodes) error('Depth or node budget exceeded');
    ws(); const c = text[at];
    if (c === '"') return string();
    if (c === '{') {
      at++; ws(); const out = {}, seen = new Set();
      if (text[at] === '}') { at++; return out; }
      while (true) {
        ws(); const key = string(true);
        if (seen.has(key)) error('Duplicate object key');
        seen.add(key); if (seen.size > cap.keys) error('Object key count budget exceeded');
        ws(); if (text[at++] !== ':') error('Expected colon');
        Object.defineProperty(out, key, {value: value(depth + 1), enumerable: true, writable: true, configurable: true});
        ws(); const end = text[at++];
        if (end === '}') return out;
        if (end !== ',') error('Expected object separator');
      }
    }
    if (c === '[') {
      at++; ws(); const out = [];
      if (text[at] === ']') { at++; return out; }
      while (true) {
        if (out.length >= cap.array) error('Array count budget exceeded');
        out.push(value(depth + 1)); ws(); const end = text[at++];
        if (end === ']') return out;
        if (end !== ',') error('Expected array separator');
      }
    }
    for (const [word, result] of [['true', true], ['false', false], ['null', null]]) {
      if (text.startsWith(word, at)) { at += word.length; return result; }
    }
    const number = /^-?(?:0|[1-9][0-9]*)/.exec(text.slice(at));
    if (!number) error('Invalid JSON value');
    at += number[0].length;
    if (/[.eE0-9]/.test(text[at] || 'x')) error('Only integer JSON tokens are supported');
    const parsed = Number(number[0]);
    if (!Number.isSafeInteger(parsed)) error('Safe integer required');
    return parsed;
  }
  const result = value(0); ws(); if (at !== text.length) error('Trailing content');
  return result;
}
const MAGIC = Buffer.from('DPV4PK01');
const memberId = /^[des]:[a-z][a-z0-9_.-]*$/;
function pack(entries) {
  if (entries.length > LIMITS.members) throw Error('Pack member count budget exceeded');
  const sorted = [...entries].sort((a,b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
  if (new Set(sorted.map(x => x.id)).size !== sorted.length) throw Error('Duplicate pack ID');
  let header = encode({schema_version: 1, members: []});
  for (let attempt = 0; attempt < 20; attempt++) {
    let offset = 12 + header.length;
    const members = sorted.map(item => {
      if (!memberId.test(item.id) || !Buffer.isBuffer(item.raw)) throw Error('Invalid pack member');
      if (item.raw.length < 1 || item.raw.length > LIMITS.scope) throw Error('Member byte budget exceeded');
      const entry = {id: item.id, offset, bytes: item.raw.length, sha256: sha256(item.raw)};
      offset += item.raw.length; return entry;
    });
    const next = encode({schema_version: 1, members});
    if (next.length === header.length) {
      const prefix = Buffer.alloc(12); MAGIC.copy(prefix); prefix.writeUInt32BE(next.length, 8);
      const result = Buffer.concat([prefix, next, ...sorted.map(x => x.raw)]);
      unpack(result); return result;
    }
    header = next;
  }
  throw Error('Pack header offset convergence failed');
}
function exactKeys(value, keys, label) {
  if (!value || Array.isArray(value) || typeof value !== 'object' || canonical(Object.keys(value).sort()) !== canonical([...keys].sort())) throw Error('Unexpected ' + label + ' keys');
}
function unpack(raw) {
  if (!Buffer.isBuffer(raw) || raw.length < 12 || raw.length > LIMITS.pack || !raw.subarray(0,8).equals(MAGIC)) throw Error('Invalid pack magic or byte budget');
  const hlen = raw.readUInt32BE(8);
  if (hlen < 1 || hlen > LIMITS.header || hlen > raw.length - 12) throw Error('Invalid pack header range');
  const headerRaw = raw.subarray(12,12 + hlen), header = strictParse(headerRaw);
  exactKeys(header, ['schema_version', 'members'], 'pack header');
  if (header.schema_version !== 1 || !Array.isArray(header.members) || header.members.length > LIMITS.members || !encode(header).equals(headerRaw)) throw Error('Invalid canonical pack header');
  const members = new Map(); let end = 12 + hlen, prior = '';
  for (const item of header.members) {
    exactKeys(item, ['id','offset','bytes','sha256'], 'pack member');
    if (!memberId.test(item.id) || item.id <= prior || members.has(item.id)) throw Error('Duplicate or unordered pack ID');
    if (!Number.isSafeInteger(item.offset) || !Number.isSafeInteger(item.bytes) || item.offset < 12 + hlen || item.bytes < 1 || item.bytes > LIMITS.scope || item.offset > raw.length || item.bytes > raw.length - item.offset) throw Error('Invalid pack member range');
    if (item.offset !== end) throw Error('Pack overlap, gap, or noncontiguous range');
    if (!/^[a-f0-9]{64}$/.test(item.sha256)) throw Error('Invalid pack member digest');
    const slice = raw.subarray(item.offset, item.offset + item.bytes);
    if (sha256(slice) !== item.sha256) throw Error('Pack member digest mismatch');
    members.set(item.id, {descriptor: item, raw: slice}); prior = item.id; end = item.offset + item.bytes;
  }
  if (end !== raw.length) throw Error('Unexpected trailing pack bytes');
  return {header, headerBytes: hlen + 12, members};
}
module.exports = {LIMITS, sha256, readBounded, scalar, canonical, encode, digest, strictParse, pack, unpack, exactKeys};
