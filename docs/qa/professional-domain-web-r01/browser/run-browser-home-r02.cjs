'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {createHash} = require('node:crypto');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '../../..');
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const result = JSON.parse(fs.readFileSync(path.join(__dirname,'actual-web-build-result.json'),'utf8'));
if (!result.ok) throw Error('The actual build and persisted receipt must pass first.');
const directory = path.join(__dirname,'browser-home-r02');
if (fs.existsSync(directory)) throw Error('Browser witness is one-shot; retain previous execution.');
const receiptPath = path.join(root,'build/web-build.json');
if (digest(fs.readFileSync(receiptPath)) !== result.verification.receipt_sha256) throw Error('Build receipt changed.');
const inputs = ['tests/browser/learning-paths.spec.cjs','tests/browser/game-ui.cjs',
  'playwright.config.cjs','tools/serve-web.cjs','package.json','package-lock.json','build/web-build.json'];
const snapshot = () => inputs.map(file => {const raw=fs.readFileSync(path.join(root,file));return {path:file,bytes:raw.length,sha256:digest(raw)};});
fs.mkdirSync(directory);
const before = snapshot(), started = new Date().toISOString();
fs.writeFileSync(path.join(directory,'inputs-before.json'),JSON.stringify(before,null,2)+'\n',{flag:'wx'});
const args=['node_modules/@playwright/test/cli.js','test','tests/browser/learning-paths.spec.cjs',
  '--project=desktop-chromium','--grep=both paths and all twenty searchable careers are discoverable before media downloads',
  '--output='+path.join(directory,'artifacts'),'--reporter=list'];
const logPath=path.join(directory,'browser.log'), fd=fs.openSync(logPath,'wx');
const run=spawnSync(process.execPath,args,{cwd:root,windowsHide:true,stdio:['ignore',fd,fd],timeout:360000});
fs.closeSync(fd);
const after=snapshot();
fs.writeFileSync(path.join(directory,'inputs-after.json'),JSON.stringify(after,null,2)+'\n',{flag:'wx'});
const report={schema_version:1,kind:'professional_domain_web_home_browser_smoke',started_at:started,finished_at:new Date().toISOString(),
  command:[process.execPath,...args],exit_code:run.status,signal:run.signal,error:run.error?.message||null,
  log_sha256:digest(fs.readFileSync(logPath)),build_receipt_sha256:result.verification.receipt_sha256,
  checked_inputs_unchanged:JSON.stringify(before)===JSON.stringify(after),
  ok:run.status===0&&!run.error&&JSON.stringify(before)===JSON.stringify(after),
  scope:'One actual desktop Chromium Home test at four viewport sizes and all twenty career searches; no Professional ready gameplay, physical-device, performance, audio or runtime-owner acceptance.'};
fs.writeFileSync(path.join(directory,'receipt.json'),JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(report));
process.exitCode=report.ok?0:1;
