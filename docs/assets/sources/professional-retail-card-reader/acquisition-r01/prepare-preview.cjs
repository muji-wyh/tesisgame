'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const sharp = require('C:/Users/yaohuiwang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = __dirname;
const source = fs.readFileSync(path.join(root, '206301-browser.svg'));
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
assert.equal(sha(source), '116dca8283535b13345dbd785e846f162bd3701d91816f35603d4aead648a044');
assert(!/<(?:script|image|foreignObject|animate|set)\b|(?:href|url\s*\()|<!ENTITY/i.test(source.toString()));
async function main() {
  const full = await sharp(source, {density: 144}).png().toBuffer();
  const cropped = await sharp(full).trim({background: '#00000000'}).resize(512, 512, {fit: 'inside'}).png().toBuffer();
  const images = [];
  for (const [filename, raw] of [['206301-render.png', full], ['206301-cropped-512.png', cropped]]) {
    fs.writeFileSync(path.join(root, filename), raw, {flag: 'wx'});
    images.push({filename, bytes: raw.length, sha256: sha(raw), metadata: await sharp(raw).metadata()});
  }
  const tiles = [{input: cropped, top: 20, left: 20}];
  for (const [index, size] of [64, 96, 128, 192].entries()) {
    const tile = await sharp(cropped).resize(size, size, {fit:'contain', background:'#ffffff00'}).png().toBuffer();
    tiles.push({input:tile,top:50 + index*120,left:600});
  }
  const sheet = await sharp({create:{width:840,height:560,channels:4,background:'#f3f6f4'}}).composite(tiles).png().toBuffer();
  fs.writeFileSync(path.join(root,'206301-size-review.png'),sheet,{flag:'wx'});
  images.push({filename:'206301-size-review.png',bytes:sheet.length,sha256:sha(sheet)});
  const receipt = {schema:1,recorded_at:new Date().toISOString(),source:{filename:'206301-browser.svg',bytes:source.length,sha256:sha(source)},images,source_page:'https://freesvg.org/pos-termina-credit-card-payment',publisher:'publicdomainvectors.org',individual_creator:'Not identified by page or SVG metadata',source_license:'Public domain; site links CC0 1.0',animations:0,external_resources:0,integrated:false,human_visual_acceptance:false,scope:'Source acquisition and raster inspection only; no production or candidate curriculum mutation.'};
  fs.writeFileSync(path.join(root,'preparation-receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
  console.log(JSON.stringify(receipt));
}
main().catch(error=>{console.error(error);process.exitCode=1;});
