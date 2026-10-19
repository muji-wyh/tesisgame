'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {createHash} = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const preimages = path.join(__dirname,'preimages');
if (fs.existsSync(preimages)) throw Error('Integration preimages already exist; do not replay.');
const sources = [
  ['professional_domain_owner.gd','a5d38afb67e53eede47fc2a50bec1e42060c39597021d3c0774be8cd45855feb'],
  ['professional_domain_catalog.gd','9b9959ecf79894abfd1f6ec279bf597987e68068bd0d3ef5f257c8237f574b19'],
  ['professional_catalog.gd','a80f9f847e515f882bc2ef94c2a284d6938ea811b4a7ac64882f90223909467b']
];
for (const [name, expected] of sources) {
  if (digest(fs.readFileSync(path.join(root,'build/professional-english/domain-runtime-staging-r01/scripts',name))) !== expected) throw Error('Frozen staging drift.');
  if (name !== 'professional_catalog.gd' && fs.existsSync(path.join(root,'scripts',name))) throw Error('Unexpected existing owner/adapter.');
}
if (digest(fs.readFileSync(path.join(root,'scripts/professional_catalog.gd'))) !== '89865c3e86d2140d6b495461632a4a16ecf6eb1bd03e0d2ce4902cce33eeb15e') throw Error('Catalog preimage drift.');
const existing = ['scripts/professional_catalog.gd','scripts/professional_play.gd','scripts/game_ui.gd',
  'tests/godot/professional_play_tests.gd','tests/godot/professional_application_flow_tests.gd',
  'docs/plans/professional-english-checkpoint.md'];
const records = [];
for (const name of existing) {
  const raw = fs.readFileSync(path.join(root,name));
  const target = path.join(preimages,name);
  fs.mkdirSync(path.dirname(target),{recursive:true});
  fs.writeFileSync(target,raw,{flag:'wx'});
  records.push({path:name,bytes:raw.length,sha256:digest(raw)});
}
for (const [name] of sources) fs.copyFileSync(path.join(root,'build/professional-english/domain-runtime-staging-r01/scripts',name),path.join(root,'scripts',name));
fs.writeFileSync(path.join(__dirname,'preimages.json'),JSON.stringify({schema_version:1,created_at:new Date().toISOString(),files:records,installed:sources.map(([name,sha256])=>({path:'scripts/'+name,sha256}))},null,2)+'\n',{flag:'wx'});
console.log('Frozen owner, private catalog and catalog helper installed; root preimages preserved. No runtime acceptance granted.');
