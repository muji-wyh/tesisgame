'use strict';
// Browser-only supplement of the reviewed r04 export. Scenario and assertions are inherited unchanged.
const assert = require('node:assert/strict'), http = require('node:http');
const c = require('./common.cjs');
const {fs,path,base,root,attempt,web,json,read,write,binding,assertReferences,assertBindings,assertHarness} = c;
const {assertInherited,assertShellReceipt} = require('./supplement.cjs');
const harness = assertHarness(), inherited = assertInherited();
const supplement = read(path.join(attempt,'shell-supplement.json'));
assertShellReceipt(supplement,inherited,harness);
// This in-memory view keeps the original audited release and binds the separately copied shell outputs.
const exported = {...inherited.exported,outputs:supplement.outputs};
if (!exported.ok) throw Error('The isolated export and actual raw-PCK proof must pass first.');
const exportBinding = inherited.export_receipt;
const supplementBinding = binding(path.join(attempt,'shell-supplement.json'));
assertReferences(); assertBindings(web,exported.outputs);
const directory = path.join(attempt,'browser');
if (fs.existsSync(directory)) throw Error('Browser evidence is one-shot; preserve the previous run.');
fs.mkdirSync(directory);
const {chromium} = require(path.join(root,'node_modules/@playwright/test'));
const {validatePackProof} = require(path.join(root,'tools/professional-domain-web.cjs'));
const requests = [], messages = [], pageErrors = [], observations = [];
const mime = {'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8',
  '.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png','.wav':'audio/wav','.json':'application/json'};
const server = http.createServer((request,response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url,'http://localhost').pathname);
    const filename = path.resolve(web,'.'+(pathname==='/'?'/index.html':pathname));
    const lower = value => process.platform==='win32'?value.toLowerCase():value;
    if (!lower(filename).startsWith(lower(web)+path.sep)) throw Error('Path outside fixture');
    const stat = fs.lstatSync(filename);
    if (!stat.isFile() || stat.isSymbolicLink()) throw Error('Not a regular fixture output');
    requests.push({path:pathname,bytes:stat.size});
    response.writeHead(200,{'Content-Type':mime[path.extname(filename)]||'application/octet-stream','Content-Length':stat.size,
      'Cache-Control':'no-store','Cross-Origin-Opener-Policy':'same-origin','Cross-Origin-Embedder-Policy':'require-corp'});
    fs.createReadStream(filename).pipe(response);
  } catch (_) { response.writeHead(404); response.end('Fixture output unavailable'); }
});
(async () => {
  let browser, page, receipt, last = null;
  const started = new Date().toISOString();
  try {
    await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve);});
    const url = 'http://127.0.0.1:'+server.address().port+'/';
    browser = await chromium.launch({headless:true});
    const context = await browser.newContext({viewport:{width:1000,height:900}});
    page = await context.newPage();
    page.on('console',message=>messages.push({type:message.type(),text:message.text()}));
    page.on('pageerror',error=>pageErrors.push(String(error)));
    async function state(label) {
      const value = await page.evaluate(()=>({snapshot:window.domainFixture.snapshot,host:window.domainFixture.stats(),
        engine_error:window.domainFixture.engineError}));
      observations.push({label,...value}); last=value; return value;
    }
    async function wait(status,caseName) {
      await page.waitForFunction(({status,caseName})=>{
        const fixture=window.domainFixture;
        if (fixture?.engineError) throw Error(fixture.engineError);
        const current=fixture?.snapshot;
        if (current?.failures?.length) throw Error(current.failures.join('; '));
        return current?.case_status===status && (!caseName || current.case===caseName);
      },{status,caseName},{timeout:120000});
      return state(caseName+':'+status);
    }
    await page.goto(url,{waitUntil:'domcontentloaded',timeout:30000});
    const boot = await wait('idle','boot');
    validatePackProof(exported.release,boot.snapshot.pack_proof);
    assert.equal(boot.host.media_requests,0);
    assert.equal(boot.snapshot.owner.installed,false);

    await page.click('#cold');
    const cold = await wait('ready','cold');
    assert.equal(cold.snapshot.owner.last_request.ok,true);
    assert.equal(cold.snapshot.owner.last_request.warm_cache_hit,false);
    assert(cold.snapshot.owner.last_request.policy_file_reads>0);
    assert.equal(cold.snapshot.owner.last_request.manifest_file_reads,1);
    assert.equal(cold.snapshot.summary.context.mode,'phrase');
    assert.equal(cold.snapshot.summary.module_words,50);
    assert.equal(cold.snapshot.summary.expressions,10);
    assert(cold.host.media_requests>0);
    assert(cold.host.operations.some(item=>item.operation==='register'));
    assert(cold.host.operations.some(item=>item.operation==='context'));
    await page.click('#claim');
    const first = await wait('claimed','cold');
    assert.equal(first.snapshot.cache.leases,1);
    assert(first.snapshot.picture_bound && first.snapshot.audio_bound && first.snapshot.last_scope_accessible);

    await page.click('#warm');
    const warm = await wait('ready','warm');
    assert.equal(warm.snapshot.owner.last_request.warm_cache_hit,true);
    assert.equal(warm.snapshot.owner.last_request.policy_file_reads,0);
    assert.equal(warm.snapshot.owner.last_request.manifest_file_reads,0);
    assert.equal(warm.snapshot.owner.policy_file_reads,cold.snapshot.owner.policy_file_reads);
    assert.equal(warm.snapshot.owner.manifest_file_reads,cold.snapshot.owner.manifest_file_reads);
    assert.equal(warm.host.media_requests,cold.host.media_requests);
    assert.equal(warm.snapshot.cache.leases,2);
    await page.click('#claim');
    const second = await wait('claimed','warm');
    assert.equal(second.snapshot.cache.leases,1);
    assert.equal(second.snapshot.ready_count,2);
    assert.equal(second.snapshot.claim_count,2);
    await page.screenshot({path:path.join(directory,'phrase-runtime.png'),fullPage:true});

    await page.click('#cancel_checkpoint');
    await wait('cancelled','cancel_checkpoint');
    await page.waitForFunction(()=>window.domainFixture.snapshot.phase==='idle' &&
      window.domainFixture.snapshot.session.pending_count===0,null,{timeout:30000});
    const cancelled = await state('cancelled-and-restored');
    assert.equal(cancelled.snapshot.ready_count,2);
    assert.equal(cancelled.snapshot.owner.active_tokens,0);
    assert.equal(cancelled.snapshot.owner.active_jobs,0);
    assert.equal(cancelled.snapshot.owner.open_files,0);
    assert.equal(cancelled.snapshot.cache.leases,1);
    assert(cancelled.snapshot.last_scope_accessible);

    await page.click('#retire_storage');
    const held = await wait('storage_held','retire_storage');
    assert.equal(held.snapshot.phase,'storage');
    assert.equal(held.host.held,1);
    assert.equal(held.snapshot.cache.leases,2);
    await page.click('#retire');
    await wait('retired','retire_storage');
    await page.waitForFunction(()=>window.domainFixture.snapshot.phase==='idle' &&
      window.domainFixture.snapshot.session.pending_count===0,null,{timeout:30000});
    const retired = await state('retired-and-restored');
    assert.equal(retired.snapshot.owner.closed,true);
    assert.equal(retired.snapshot.owner.active_tokens,0);
    assert.equal(retired.snapshot.ready_count,2);
    assert.equal(retired.snapshot.invalidated_count,1);
    assert.equal(retired.snapshot.cache.leases,1);
    assert.equal(retired.host.held,0);
    assert.equal(retired.host.held_released,1);
    assert(retired.snapshot.last_scope_accessible);

    await page.click('#dispose');
    await wait('disposed','retire_storage');
    await page.waitForFunction(()=>window.domainFixture.snapshot.owner_alive===false &&
      window.domainFixture.snapshot.cache_alive===false,null,{timeout:30000});
    const disposed = await state('disposed-and-freed');
    assert.equal(disposed.snapshot.disposed.cache.leases,0);
    assert.equal(disposed.snapshot.disposed.owner.cached_modules,0);
    assert.equal(disposed.snapshot.disposed.owner.open_files,0);
    assert.equal(disposed.snapshot.disposed.store_closed,true);
    assert.equal(disposed.snapshot.disposed.store_pending,0);
    assert.equal(disposed.snapshot.disposed.store_callbacks,0);
    assert.equal(disposed.snapshot.disposed.store_timers,0);
    assert.equal(disposed.snapshot.disposed.last_scope_accessible,false);
    assert.equal(pageErrors.length,0);
    assert(!messages.some(item=>/(?:SCRIPT )?ERROR:/.test(item.text)));
    assertReferences(); assertHarness(); assertBindings(web,exported.outputs);
    assertInherited(); assertShellReceipt(supplement,inherited,harness);
    receipt={schema:1,ok:true,started_at:started,finished_at:new Date().toISOString(),url,synthetic_only:true,mode:'phrase',
      harness_inventory:harness,export_receipt:exportBinding,shell_supplement_receipt:supplementBinding,inherited_inputs:inherited.inherited_inputs,
      real_owner:true,real_media_bridge:true,real_indexeddb:true,owner_test_double:false,caller_pin_override:false,
      sources_unchanged:true,web_outputs_unchanged:true,observations,requests,page_errors:pageErrors,
      scope:'Actual isolated Web ready/claim, warm zero policy and manifest reads, checkpoint cancellation, retirement during a delayed real storage callback, and fixture-owned resource disposal.',
      unproven:['full game_ui.new_round and view teardown','other five real modes','accepted answer/wallet/outbox settlement','physical devices','audibility','performance and memory targets']};
  } catch(error) {
    if(page) {
      try { last=await page.evaluate(()=>({snapshot:window.domainFixture?.snapshot,host:window.domainFixture?.stats(),engine_error:window.domainFixture?.engineError})); } catch(_) {}
      try { await page.screenshot({path:path.join(directory,'failure.png'),fullPage:true}); } catch(_) {}
    }
    receipt={schema:1,ok:false,started_at:started,finished_at:new Date().toISOString(),error:error.stack||String(error),
      harness_inventory:harness,export_receipt:exportBinding,shell_supplement_receipt:supplementBinding,inherited_inputs:inherited.inherited_inputs,
      synthetic_only:true,last,observations,requests,page_errors:pageErrors};
    process.exitCode=1;
  } finally {
    const cleanupErrors = [];
    try { if(browser) await browser.close(); } catch(error) { cleanupErrors.push(String(error)); }
    try { await new Promise(resolve=>server.close(resolve)); } catch(error) { cleanupErrors.push(String(error)); }
    if (cleanupErrors.length) {
      receipt.ok = false; receipt.cleanup_errors = cleanupErrors; process.exitCode = 1;
    }
    write(path.join(directory,'console.json'),json(messages));
    write(path.join(directory,'receipt.json'),json(receipt));
    process.stdout.write(json({ok:receipt.ok,receipt:path.join(directory,'receipt.json'),error:receipt.error||null}));
  }
})().catch(error=>{process.stderr.write(error.stack+'\n');process.exitCode=1;});

