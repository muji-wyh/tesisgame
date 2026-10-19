'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {createHash} = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const result = JSON.parse(fs.readFileSync(path.join(__dirname, 'actual-web-build-result.json'), 'utf8'));
const target = path.join(root, 'docs/qa/professional-domain-web-r01');
if (fs.existsSync(target)) throw Error('Durable result already exists; preserve it unchanged.');
if (result.log_sha256 !== digest(fs.readFileSync(path.join(__dirname, 'actual-web-build.log')))) throw Error('Build log hash mismatch.');
fs.mkdirSync(target);
const files = [];
function copy(source, relative) {
  const bytes = fs.readFileSync(source);
  const destination = path.join(target, relative);
  fs.mkdirSync(path.dirname(destination), {recursive:true});
  fs.writeFileSync(destination, bytes, {flag:'wx'});
  if (!fs.readFileSync(source).equals(bytes) || !fs.readFileSync(destination).equals(bytes)) throw Error('Copy changed: ' + relative);
  files.push({path:relative,source:path.relative(root,source).replaceAll('\\','/'),bytes:bytes.length,sha256:digest(bytes)});
}
function copyTree(source, relative) {
  for (const item of fs.readdirSync(source,{withFileTypes:true})) {
    if (item.isSymbolicLink()) throw Error('Evidence symlink rejected.');
    if (item.isDirectory()) copyTree(path.join(source,item.name),path.posix.join(relative,item.name));
    else copy(path.join(source,item.name),path.posix.join(relative,item.name));
  }
}
for (const filename of ['run-build.cjs','preserve-result.cjs','actual-web-build-result.json','actual-web-build.log',
  'build-inputs-before.json','build-inputs-after.json','focused-checks.json','node-results-tail.log','preimages.json']) copy(path.join(__dirname, filename), filename);
for (const filename of ['prior-web-build.json','verified-web-build.json']) if (fs.existsSync(path.join(__dirname,filename))) copy(path.join(__dirname,filename),filename);
copyTree(path.join(__dirname,'preimages'),'preimages');
if (result.ok) {
  const work = result.verification.retained_work_dir;
  if (!path.resolve(work).toLowerCase().startsWith(path.join(root,'build').toLowerCase() + path.sep)) throw Error('Unexpected retained package root.');
  for (const filename of ['source-capture.json','compile-report.json','audit-report.json','prepared-release.json',
    'installed-release.json','web-pack-manifest.json','web-pack-proof.json']) copy(path.join(work,filename),'package/'+filename);
  for (const item of result.verification.generated_inventory) {
    const source = path.join(root,item.path.slice(6));
    if (digest(fs.readFileSync(source)) !== item.sha256) throw Error('Generated artifact drift: '+item.path);
    copy(source,'generated/'+path.basename(source));
  }
  copy(path.join(root,'scripts/professional_domain_release.gd'),'generated/professional_domain_release.gd');
}
const receipt = {schema_version:1,kind:'professional_domain_web_durable_copy',created_at:new Date().toISOString(),
  actual_build_ok:result.ok,files:files.sort((a,b)=>a.path.localeCompare(b.path,'en')),
  copies_byte_identical:true,source_snapshot_retained_at:result.verification?.retained_work_dir || null,
  scope:'Exact local build evidence only. No deployment, runtime-owner integration, gameplay, device, listening or curriculum acceptance.'};
const raw=Buffer.from(JSON.stringify(receipt,null,2)+'\n');
fs.writeFileSync(path.join(target,'copy-receipt.json'),raw,{flag:'wx'});
console.log(JSON.stringify({target,files:files.length,copy_receipt_sha256:digest(raw),build_ok:result.ok}));
