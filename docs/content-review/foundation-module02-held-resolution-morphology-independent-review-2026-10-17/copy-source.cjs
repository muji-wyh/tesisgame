'use strict';
// One-shot exact archival copy. Built-in modules only; no project execution.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
const destination = 'docs/content-review/foundation-module02-held-resolution-morphology-independent-review-2026-10-17';
const groups = [
  {source:'build/professional-english/foundation02-held-resolution-morphology-research-r01',folder:'research',inventory:'9ecff44931f5512774c98ef4781d1720d3fdb416855dd53e6e56b065cb0d6741'},
  {source:'build/professional-english/foundation02-held-resolution-morphology-independent-review-r01',folder:'independent-review',inventory:'474dd910308eef8dcf9542099f35023e19b482a238e6cd731632e07a7a84735b'}
];
const sha = b => crypto.createHash('sha256').update(b).digest('hex');
const normalize = p => p.split(path.sep).join('/');
const destinationAbs = path.resolve(root, destination);
if (!destinationAbs.startsWith(root + path.sep) || !destination.startsWith('docs/content-review/')) throw Error('Destination escaped workspace.');
const attempt = path.join(__dirname, 'attempt.json');
fs.writeFileSync(attempt, JSON.stringify({started_at:new Date().toISOString(),script_sha256:sha(fs.readFileSync(__filename)),destination},null,2)+'\n',{flag:'wx'});
const items=[];
const copied=[];
try {
  if(fs.existsSync(destinationAbs)) throw Error('Fresh destination already exists.');
  for(const group of groups){
    const sourceAbs=path.resolve(root,group.source);
    if(!sourceAbs.startsWith(root+path.sep)) throw Error('Source escaped workspace.');
    const inventoryBytes=fs.readFileSync(path.join(sourceAbs,'inventory.json'));
    if(sha(inventoryBytes)!==group.inventory) throw Error('Frozen source inventory mismatch: '+group.source);
    const inventory=JSON.parse(inventoryBytes);
    if(inventory.inventory_excludes_itself!==true || inventory.files.length!==14) throw Error('Unexpected inventory structure.');
    const expected=new Set(['inventory.json']);
    for(const row of inventory.files){
      if(!/^[A-Za-z0-9_.-]+$/.test(row.path)||row.path==='inventory.json'||expected.has(row.path)) throw Error('Invalid or duplicate member path.');
      expected.add(row.path);
      const b=fs.readFileSync(path.join(sourceAbs,row.path));
      if(b.length!==row.bytes||sha(b)!==row.sha256) throw Error('Frozen source member mismatch: '+row.path);
      items.push({source:group.source+'/'+row.path,destination:group.folder+'/'+row.path,bytes:b.length,sha256:sha(b),buffer:b});
    }
    const actual=fs.readdirSync(sourceAbs,{withFileTypes:true});
    if(actual.length!==expected.size||actual.some(row=>!row.isFile()||!expected.has(row.name))) throw Error('Unlisted source member: '+group.source);
    items.push({source:group.source+'/inventory.json',destination:group.folder+'/inventory.json',bytes:inventoryBytes.length,sha256:sha(inventoryBytes),buffer:inventoryBytes});
  }
  const own=fs.readFileSync(__filename);
  items.push({source:normalize(path.relative(root,__filename)),destination:'copy-source.cjs',bytes:own.length,sha256:sha(own),buffer:own});
  fs.mkdirSync(destinationAbs);
  for(const group of groups)fs.mkdirSync(path.join(destinationAbs,group.folder));
  for(const item of items){
    const target=path.resolve(destinationAbs,item.destination);
    if(!target.startsWith(destinationAbs+path.sep))throw Error('Copy target escaped destination.');
    fs.writeFileSync(target,item.buffer,{flag:'wx'});
    const actual=fs.readFileSync(target);
    if(actual.length!==item.bytes||sha(actual)!==item.sha256)throw Error('Copied bytes mismatch.');
    copied.push({source:item.source,destination:item.destination,bytes:item.bytes,sha256:item.sha256});
  }
  const readme=`# Held-resolution morphology: research and independent review

This archive preserves the exact frozen author research and independent AI morphology review. No graph is activated by this copy.

The accepted [structure projection](independent-review/accepted-analysis-structure.json) contains causative **en- + sure**, intact **inform**, and intact gathering **collect**. Its SHA256 is \`a14730c9239eff17513700bc126e960a68c2a8f0100e259a7b297a92acc4dd6c\`. The [independent decision](independent-review/review.json), SHA256 \`b330dc32283ccb3498a355e3233c844364a65d4b52b7ffedb7e65351f8d53123\`, accepts only schema, target identity/text, kind, parts, nodes and roots. Final analysis IDs and review/status/reference/note metadata are unbound and need a separate delivery proposal. The author's pending metadata is preserved without promotion.

The accepted lexical forms **ensure** and **insure** remain unchanged. The selected graph spells canonical ensure; the atomic ensure fallback is unselected. Clinical inform, pickup collect, other en- and -en families, and assure/assurance remain pending separate decisions. Atomic exposure is not assessed spelling mastery. Changing collect's part identity cannot certify old pickup-derived learning evidence.

Nine freshly consulted Oxford/Collins sources support the bounded AI decision. Neither source consultation nor this review constitutes human specialist, media, exercise, module or release acceptance. Final registry/source/revision binding, canonical-collision checks, variant handling, populated-profile semantics and integrated verification remain pending.

The review's fresh raw-data capture passed 5,373 comparisons over 194 immutable inputs. Eight live author pins were deliberately not read; three runtime files were inspected through exact immutable equivalents. This is static evidence only. All author research, the original reviewer capture failure, the successful fresh r02 capture and the later family supplement are retained exactly. The first failure compared an extra disposition annotation with a bare corpus wrapper; r02 compares complete resource and entry fields while keeping that annotation as commentary. Do not replay the consumed scripts.

## Archive contents

- [research/inventory.json](research/inventory.json): exact author inventory and fourteen payload files; inventory SHA256 \`9ecff44931f5512774c98ef4781d1720d3fdb416855dd53e6e56b065cb0d6741\`.
- [independent-review/inventory.json](independent-review/inventory.json): exact independent inventory and fourteen payload files; inventory SHA256 \`474dd910308eef8dcf9542099f35023e19b482a238e6cd731632e07a7a84735b\`.
- [copy-source.cjs](copy-source.cjs): exact archival copy of the consumed built-in-only copy script, retained as evidence and not for replay.
- [copy-receipt.json](copy-receipt.json): source and destination hashes for thirty evidence files and the copy script, plus this README hash. It records source verification before copying, destination verification, and source rechecks afterward.

Historical embedded paths and statuses are intentionally unchanged. Original source references do not become current-state bindings merely because the files are durable. No project module, test, native command, browser, live save or production/shared file was executed, inspected for activation or changed by this copy. Root retains production and serialized validation ownership.
`;
  fs.writeFileSync(path.join(destinationAbs,'README.md'),readme,{flag:'wx'});
  const readmeBytes=fs.readFileSync(path.join(destinationAbs,'README.md'));
  for(const item of items){
    const original=fs.readFileSync(path.join(root,item.source));
    const target=fs.readFileSync(path.join(destinationAbs,item.destination));
    if(original.length!==item.bytes||sha(original)!==item.sha256||target.length!==item.bytes||sha(target)!==item.sha256)throw Error('Final exact-copy/source check failed: '+item.source);
  }
  const receipt={schema:1,status:'passed_exact_durable_copy',copied_at:new Date().toISOString(),author:'Codex morph_review',destination,source_inventories:groups.map(g=>({path:g.source+'/inventory.json',sha256:g.inventory})),evidence_files:30,copy_script_files:1,total_exact_copies:copied.length,copies:copied,readme:{path:'README.md',bytes:readmeBytes.length,sha256:sha(readmeBytes)},source_rows_verified_before_copy:true,source_and_destination_rechecked_after_copy:true,failed_capture_preserved:true,fresh_r02_capture_preserved:true,author_or_review_evidence_changed:false,project_code_tests_native_or_browser_executed:false,production_or_shared_files_changed:false,live_saves_inspected:false,graphs_activated:false,final_live_binding:'UNBOUND'};
  fs.writeFileSync(path.join(destinationAbs,'copy-receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
  const result={status:'passed',destination,total_exact_copies:copied.length,receipt_sha256:sha(fs.readFileSync(path.join(destinationAbs,'copy-receipt.json'))),readme_sha256:sha(readmeBytes),copy_script_sha256:sha(own)};
  fs.writeFileSync(path.join(__dirname,'result.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
  console.log(JSON.stringify(result));
}catch(error){
  fs.writeFileSync(path.join(__dirname,'failure.json'),JSON.stringify({status:'failed',failed_at:new Date().toISOString(),error:String(error.stack||error),copied},null,2)+'\n',{flag:'wx'});
  console.error(String(error.stack||error));process.exitCode=1;
}
