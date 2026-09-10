const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

test('the delivery preset exports a single-threaded Godot Web game with JSON data', () => {
  const filename = path.join(root, 'export_presets.cfg');
  assert.ok(fs.existsSync(filename), 'The Web export preset is missing');
  const preset = fs.readFileSync(filename, 'utf8');
  assert.match(preset, /platform="Web"/);
  assert.match(preset, /variant\/thread_support=false/);
  assert.match(preset, /variant\/extensions_support=false/);
  assert.match(preset, /include_filter="[^"]*words\.json[^"]*assets\/chests\/manifest\.json/);
  assert.match(preset, /html\/custom_html_shell="res:\/\/web\/shell\.html"/);
  assert.match(preset, /html\/canvas_resize_policy=0/);
  assert.match(preset, /html\/focus_canvas_on_start=false/);
  const project = fs.readFileSync(path.join(root, 'project.godot'), 'utf8');
  assert.match(project, /textures\/vram_compression\/import_s3tc_bptc=true/);
  assert.match(project, /textures\/vram_compression\/import_etc2_astc=true/);
});

test('the export shell hosts the engine and fits a safe-area container without disabling zoom', () => {
  const filename = path.join(root, 'web', 'shell.html');
  assert.ok(fs.existsSync(filename), 'The Godot Web shell is missing');
  const shell = fs.readFileSync(filename, 'utf8');
  assert.match(shell, /\$GODOT_URL/);
  assert.match(shell, /\$GODOT_CONFIG/);
  assert.match(shell, /<canvas\b/);
  assert.match(shell, /safe-area-inset/);
  assert.match(shell, /ResizeObserver/);
  assert.match(shell, /prefers-reduced-motion/);
  assert.match(shell, /visibilitychange/);
  assert.match(shell, /engineReady/);
  assert.match(shell, /id="game-status"/);
  assert.match(shell, /id="audio-status"/);
  assert.match(shell, /--audio-driver/);
  assert.match(shell, /Dummy/);
  assert.doesNotMatch(shell, /user-scalable\s*=\s*no|maximum-scale\s*=\s*1/);
  assert.doesNotMatch(shell, /GameCore|selectCard|createRound|speechSynthesis/);
});

test('the Godot command runner waits for the engine and propagates its real failure status', () => {
  const filename = path.join(root, 'tools', 'run-godot.cjs');
  assert.ok(fs.existsSync(filename), 'The Godot process runner is missing');
  const { runGodot } = require(filename);
  assert.match(runGodot(['--version']).stdout, /^4\.7\./);
  assert.throws(
    () => runGodot(['--headless', '--path', root, '--script', 'res://tests/godot/exit_code.gd']),
    /exit 7/
  );
});

test('accessible help describes the current controls rather than the removed motion menu', () => {
  const shell = fs.readFileSync(path.join(root, 'web', 'shell.html'), 'utf8');
  const help = shell.match(/<p\b[^>]*id="help"[^>]*>([\s\S]*?)<\/p>/)?.[1];
  assert.ok(help, 'The canvas needs accessible gameplay instructions.');
  assert.doesNotMatch(help, /\bFX\b|season menu|Reduce motion button/i);
  assert.match(help, /device.*reduced-motion/i);
});

test('Web delivery compresses and fingerprints assets without mixing cached game versions', (t) => {
  const filename = path.join(root, 'tools', 'package-web.cjs');
  assert.ok(fs.existsSync(filename), 'The mobile Web export packager is missing');
  const { packageWebExport } = require(filename);
  const { brotliDecompressSync } = require('node:zlib');
  const directory = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'word-buddies-web-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const files = {
    'index.js': Buffer.from(startupFixture),
    'index.wasm': Buffer.from('engine bytecode '.repeat(8192)),
    'index.audio.worklet.js': Buffer.from('audio worklet'),
    'index.audio.position.worklet.js': Buffer.from('position worklet'),
    'index.pck': Buffer.from('game data '.repeat(1024))
  };
  const audio = [{
    source: 'res://assets/audio/voice/welcome.wav',
    bytes: Buffer.from('RSRC optional audio '.repeat(1024))
  }];
  const writeExport = () => {
    for (const [name, bytes] of Object.entries(files)) fs.writeFileSync(path.join(directory, name), bytes);
    fs.writeFileSync(path.join(directory, 'index.html'),
      `<script src="index.js"></script><script>const config = ${JSON.stringify({
        executable: 'index', args: [], fileSizes: {
          'index.wasm': files['index.wasm'].length,
          'index.pck': files['index.pck'].length
        }
      })};</script>`);
  };
  const readConfig = () => JSON.parse(fs.readFileSync(path.join(directory, 'index.html'), 'utf8')
    .match(/const config = (\{[^\r\n]*\});/)[1]);
  writeExport();
  fs.writeFileSync(path.join(directory, 'keep.txt'), 'unrelated file');
  const initialBytes = packageWebExport(directory, audio);
  const first = readConfig();
  assert.match(first.executable, /^engine-[a-f0-9]{16}$/);
  assert.match(first.mainPack, /^game-[a-f0-9]{16}\.pck$/);
  const digest = require('node:crypto').createHash('sha256');
  for (const [name, bytes] of Object.entries(files).filter(([name]) => !name.endsWith('.pck'))) {
    digest.update(name.slice('index.'.length)).update(name === 'index.js'
      ? require('../tools/patch-web-engine.cjs').patchWebEngine(bytes.toString()) : bytes);
  }
  assert.equal(first.executable, `engine-${digest.digest('hex').slice(0, 16)}`, 'Cache keys must hash the patched engine');
  for (const [name, bytes] of Object.entries(files)) {
    const target = name.endsWith('.pck') ? first.mainPack : name.replace('index', first.executable);
    const expected = name === 'index.js'
      ? Buffer.from(require('../tools/patch-web-engine.cjs').patchWebEngine(bytes.toString())) : bytes;
    assert.deepEqual(fs.readFileSync(path.join(directory, target)), expected);
    assert.deepEqual(brotliDecompressSync(fs.readFileSync(path.join(directory, `${target}.br`))), expected);
    assert.equal(fs.existsSync(path.join(directory, name)), false, 'Unversioned engine/data files must not be shipped');
  }
  assert.equal(first.fileSizes[`${first.executable}.wasm`], files['index.wasm'].length);
  assert.equal(first.fileSizes[first.mainPack], files['index.pck'].length);
  assert.ok(fs.readFileSync(path.join(directory, 'index.html'), 'utf8').includes(`src="${first.executable}.js"`));
  assert.ok(fs.statSync(path.join(directory, `${first.executable}.wasm.br`)).size < files['index.wasm'].length / 4);
  assert.ok(first.audioAssets, 'Optional audio needs an on-demand URL map');
  const firstAudio = first.audioAssets[audio[0].source];
  assert.match(firstAudio, /^audio-[a-f0-9]{16}\.sample$/);
  assert.deepEqual(fs.readFileSync(path.join(directory, firstAudio)), audio[0].bytes);
  assert.deepEqual(brotliDecompressSync(fs.readFileSync(path.join(directory, `${firstAudio}.br`))), audio[0].bytes);
  assert.equal(first.fileSizes[firstAudio], undefined, 'Optional audio must not participate in startup preloading');
  audio[0].bytes = Buffer.from('RSRC changed optional audio');
  writeExport();
  assert.equal(packageWebExport(directory, audio), initialBytes, 'Optional audio must not enlarge the startup payload');
  const audioUpdate = readConfig();
  assert.equal(audioUpdate.executable, first.executable);
  assert.equal(audioUpdate.mainPack, first.mainPack, 'Optional audio updates must not invalidate the game pack');
  assert.notEqual(audioUpdate.audioAssets[audio[0].source], firstAudio);
  assert.equal(fs.existsSync(path.join(directory, firstAudio)), false);

  files['index.pck'] = Buffer.from('updated game data');
  writeExport();
  packageWebExport(directory, audio);
  const second = readConfig();
  assert.equal(second.executable, first.executable, 'Game changes must reuse the cached engine');
  assert.notEqual(second.mainPack, first.mainPack, 'New game content must use a new cache key');
  assert.equal(fs.existsSync(path.join(directory, first.mainPack)), false, 'Obsolete generated packs must not accumulate');
  assert.equal(fs.readFileSync(path.join(directory, 'keep.txt'), 'utf8'), 'unrelated file');
  files['index.js'] = Buffer.from('changed Godot template');
  writeExport();
  const beforeFailure = new Map(fs.readdirSync(directory).map(name => [name, fs.readFileSync(path.join(directory, name))]));
  assert.throws(() => packageWebExport(directory, audio), /Godot Web startup patch/);
  assert.deepEqual(new Map(fs.readdirSync(directory).map(name => [name, fs.readFileSync(path.join(directory, name))])), beforeFailure,
    'An unknown engine must fail before overwriting or deleting any export file');
  const config = JSON.parse(fs.readFileSync(path.join(root, 'web', 'staticwebapp.config.json'), 'utf8'));
  assert.equal(config.globalHeaders['Cache-Control'], 'no-cache', 'HTML must discover updated asset names');
  assert.equal(config.globalHeaders.Vary, 'Accept-Encoding', 'Caches must distinguish compressed and identity responses');
  for (const route of ['/engine-*', '/game-*', '/audio-*']) {
    assert.equal(config.routes.find(entry => entry.route === route).headers['Cache-Control'],
      'public, max-age=31536000, immutable');
  }
});

function startupHarness(overrides = {}) {
  const { patchWebEngine } = require('../tools/patch-web-engine.cjs');
  const runtime = { initFS: async () => undefined };
  const sandbox = {
    Promise, Error, Response: class { constructor(body) { this.body = body; } },
    loadPath: 'index', Engine: { unload() {} },
    receiveInstance: instance => instance,
    Godot: async () => runtime,
    me: { config: { persistentPaths: ['/userfs'], getModuleConfig: () => ({}) }, rtenv: null },
    ...overrides
  };
  require('node:vm').runInNewContext(patchWebEngine(startupFixture), sandbox);
  return { sandbox, runtime, response: Promise.resolve({ clone: () => ({ body: [] }) }) };
}

async function rejectsWith(promise, expected) {
  let timer;
  try {
    await assert.rejects(Promise.race([
      promise,
      new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('Startup stayed pending')), 1000); })
    ]), error => error === expected);
  } finally {
    clearTimeout(timer);
  }
}

test('the generated startup patch rejects missing, duplicate, and changed template anchors', () => {
  const { patchWebEngine } = require('../tools/patch-web-engine.cjs');
  assert.throws(() => patchWebEngine('unrecognized engine'), /Godot Web startup patch/);
  assert.throws(() => patchWebEngine(startupFixture.repeat(2)), /Godot Web startup patch/);
  for (const marker of ['Module["instantiateWasm"](info', "'instantiateWasm': function", 'function doInit(promise)', 'getDB:(name,callback)']) {
    assert.ok(startupFixture.includes(marker));
    assert.throws(() => patchWebEngine(startupFixture.replace(marker, `${marker} changed`)), /Godot Web startup patch/);
  }
  assert.throws(() => patchWebEngine(patchWebEngine(startupFixture)), /Godot Web startup patch/);
});

test('streaming and fallback compilation failures reach initialization with the original cause', async () => {
  for (const streaming of [true, false]) {
    for (const ErrorType of [Error, RangeError]) {
      for (const synchronous of [false, true]) {
        const failure = new ErrorType('Allocation failed');
        const instantiate = synchronous ? () => { throw failure; } : async () => { throw failure; };
        const { sandbox, runtime, response } = startupHarness({
          WebAssembly: streaming ? { instantiateStreaming: instantiate } : { instantiate }
        });
        sandbox.Godot = config => {
          sandbox.Module = config;
          return sandbox.createWasm().then(() => runtime);
        };
        sandbox.me.config.getModuleConfig = () => sandbox.makeModuleConfig({ arrayBuffer: async () => new ArrayBuffer(0) });
        await rejectsWith(sandbox.doInit(response), failure);
        assert.equal(sandbox.me.rtenv, null);
      }
    }
  }
  const failure = new Error('Response body failed');
  const { sandbox } = startupHarness({ WebAssembly: {} });
  sandbox.Module = sandbox.makeModuleConfig({ arrayBuffer: async () => { throw failure; } });
  await rejectsWith(sandbox.createWasm(), failure);
  const callbackFailure = new Error('Instance initialization failed');
  const callbackHarness = startupHarness({
    WebAssembly: { instantiateStreaming: async () => ({ instance: {}, module: {} }) },
    receiveInstance() { throw callbackFailure; }
  }).sandbox;
  callbackHarness.Module = callbackHarness.makeModuleConfig({});
  await rejectsWith(callbackHarness.createWasm(), callbackFailure);
});

test('load, module, filesystem, and synchronous startup errors propagate while ordinary IDB denial stays compatible', async () => {
  for (const stage of ['load', 'clone', 'module', 'module-sync', 'filesystem', 'filesystem-sync', 'storage-blocked']) {
    const failure = new Error(stage);
    const { sandbox, runtime, response } = startupHarness();
    let load = response;
    if (stage === 'load') load = Promise.reject(failure);
    if (stage === 'clone') load = Promise.resolve({ clone() { throw failure; } });
    if (stage === 'module') sandbox.Godot = async () => { throw failure; };
    if (stage === 'module-sync') sandbox.Godot = () => { throw failure; };
    if (stage === 'filesystem') runtime.initFS = async () => { throw failure; };
    if (stage === 'filesystem-sync') runtime.initFS = () => { throw failure; };
    if (stage === 'storage-blocked') {
      failure.name = 'StorageBlockedError';
      runtime.initFS = async () => failure;
    }
    await rejectsWith(sandbox.doInit(load), failure);
    assert.equal(sandbox.me.rtenv, null);
  }
  const { sandbox, runtime, response } = startupHarness();
  runtime.initFS = async () => new DOMException('Private browser', 'SecurityError');
  await sandbox.doInit(response);
  assert.equal(sandbox.me.rtenv, runtime);
});

test('blocked IDB upgrades fail once, abort late migration, and close late connections without caching them', () => {
  const { sandbox } = startupHarness();
  const request = {};
  sandbox.IDBFS.indexedDB = () => ({ open: () => request });
  const results = [];
  sandbox.IDBFS.getDB('/userfs', (...args) => results.push(args));
  request.onblocked();
  request.onblocked();
  assert.equal(results.length, 1);
  assert.equal(results[0][0].name, 'StorageBlockedError');
  assert.match(results[0][0].message, /close.*other.*game.*tab/i);
  let aborted = 0;
  request.onupgradeneeded({ target: { transaction: { abort() { aborted++; } } } });
  assert.equal(aborted, 1);
  let prevented = 0;
  request.onerror({ target: { error: new Error('AbortError') }, preventDefault() { prevented++; } });
  let closed = 0;
  request.result = { close() { closed++; } };
  request.onsuccess();
  assert.equal(prevented, 1);
  assert.equal(closed, 1);
  assert.equal(results.length, 1);
  assert.equal(sandbox.IDBFS.dbs['/userfs'], undefined);
});

test('normal IDB connections remain cached and access denial keeps its original error', () => {
  const { sandbox } = startupHarness();
  const request = { result: {} };
  sandbox.IDBFS.indexedDB = () => ({ open: () => request });
  const results = [];
  sandbox.IDBFS.getDB('/userfs', (...args) => results.push(args));
  request.onsuccess();
  assert.equal(results.length, 1);
  assert.equal(results[0][0], null);
  assert.equal(results[0][1], request.result);
  assert.equal(sandbox.IDBFS.dbs['/userfs'], request.result);
  sandbox.IDBFS.getDB('/userfs', (...args) => results.push(args));
  assert.equal(results.length, 2);
  const failure = new DOMException('Access denied', 'SecurityError');
  sandbox.IDBFS.indexedDB = () => ({ open() { throw failure; } });
  sandbox.IDBFS.getDB('/other', error => assert.equal(error, failure));
});

// Kept independently from the patch strings so template drift cannot silently pass.
const startupFixture = String.raw`// Snapshot of the relevant unmodified Godot 4.7.1 release-template code.
function createWasm() {
  const info = {};
  if(Module["instantiateWasm"]){return new Promise((resolve,reject)=>{Module["instantiateWasm"](info,(inst,mod)=>{resolve(receiveInstance(inst,mod))})})}
}
function makeModuleConfig(response) {
  let r = response;
  return {
			'instantiateWasm': function (imports, onSuccess) {
				function done(result) {
					onSuccess(result['instance'], result['module']);
				}
				if (typeof (WebAssembly.instantiateStreaming) !== 'undefined') {
					WebAssembly.instantiateStreaming(Promise.resolve(r), imports).then(done);
				} else {
					r.arrayBuffer().then(function (buffer) {
						WebAssembly.instantiate(buffer, imports).then(done);
					});
				}
				r = null;
				return {};
			},
  };
}
				function doInit(promise) {
					// Care! Promise chaining is bogus with old emscripten versions.
					// This caused a regression with the Mono build (which uses an older emscripten version).
					// Make sure to test that when refactoring.
					return new Promise(function (resolve, reject) {
						promise.then(function (response) {
							const cloned = new Response(response.clone().body, { 'headers': [['content-type', 'application/wasm']] });
							Godot(me.config.getModuleConfig(loadPath, cloned)).then(function (module) {
								const paths = me.config.persistentPaths;
								module['initFS'](paths).then(function (err) {
									me.rtenv = module;
									if (me.config.unloadAfterInit) {
										Engine.unload();
									}
									resolve();
								});
							});
						});
					});
				}

var IDBFS = { dbs: {}, DB_VERSION: 21, DB_STORE_NAME: 'FILE_DATA', getDB:(name,callback)=>{var db=IDBFS.dbs[name];if(db){return callback(null,db)}var req;try{req=IDBFS.indexedDB().open(name,IDBFS.DB_VERSION)}catch(e){return callback(e)}if(!req){return callback("Unable to connect to IndexedDB")}req.onupgradeneeded=e=>{var db=e.target.result;var transaction=e.target.transaction;var fileStore;if(db.objectStoreNames.contains(IDBFS.DB_STORE_NAME)){fileStore=transaction.objectStore(IDBFS.DB_STORE_NAME)}else{fileStore=db.createObjectStore(IDBFS.DB_STORE_NAME)}if(!fileStore.indexNames.contains("timestamp")){fileStore.createIndex("timestamp","timestamp",{unique:false})}};req.onsuccess=()=>{db=req.result;IDBFS.dbs[name]=db;callback(null,db)};req.onerror=e=>{callback(e.target.error);e.preventDefault()}} };
`;
