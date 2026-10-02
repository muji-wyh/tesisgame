// Godot 4.7.1 release export template fixes. Keep these anchors exact: an engine
// upgrade must be reviewed, not silently packaged with broken startup or audio.
const patches = [
  {
    name: "preserve fetched response while tracking download progress",
    before: `	function getTrackedResponse(response, load_status) {
		function onloadprogress(reader, controller) {
			return reader.read().then(function (result) {
				if (load_status.done) {
					return Promise.resolve();
				}
				if (result.value) {
					controller.enqueue(result.value);
					load_status.loaded += result.value.length;
				}
				if (!result.done) {
					return onloadprogress(reader, controller);
				}
				load_status.done = true;
				return Promise.resolve();
			});
		}
		const reader = response.body.getReader();
		return new Response(new ReadableStream({
			start: function (controller) {
				onloadprogress(reader, controller).then(function () {
					controller.close();
				});
			},
		}), { headers: response.headers });
	}
`,
    after: `	function getTrackedResponse(response, load_status) {
		// Keep the fetched response's browser WASM cache metadata intact.
		const reader = response.clone().body.getReader();
		async function track() {
			try {
				while (true) {
					const result = await reader.read();
					if (result.value) load_status.loaded += result.value.length;
					if (result.done) break;
				}
			} catch {
				// The original response consumer reports the same network failure.
			} finally {
				load_status.done = true;
				reader.releaseLock();
			}
		}
		track();
		return response;
	}
`
  },
  {
    name: "register the engine audio context for foreground and gesture recovery",
    before: `const ctx=new(window.AudioContext||window.webkitAudioContext)(opts);GodotAudio.ctx=ctx;ctx.onstatechange=function(){`,
    after: `const ctx=new(window.AudioContext||window.webkitAudioContext)(opts);GodotAudio.ctx=ctx;window.wordBuddiesHost?.attachAudioContext?.(ctx);ctx.onstatechange=function(){`
  },
  {
    name: "release the registered audio context when the engine closes",
    before: `close_async:function(resolve,reject){const ctx=GodotAudio.ctx;GodotAudio.ctx=null;if(!ctx){resolve();return}`,
    after: `close_async:function(resolve,reject){const ctx=GodotAudio.ctx;GodotAudio.ctx=null;GodotAudio.audioPositionWorkletReadyContext=null;window.wordBuddiesHost?.attachAudioContext?.(null);if(!ctx){resolve();return}`
  },
  {
    name: "allow later audio gesture recovery after a rejected resume",
    before: `function _godot_audio_resume(){if(GodotAudio.ctx&&GodotAudio.ctx.state!=="running"){GodotAudio.ctx.resume()}}`,
    after: `function _godot_audio_resume(){const ctx=GodotAudio.ctx;if(ctx&&ctx.state!=="running"&&ctx.state!=="closed"){try{Promise.resolve(ctx.resume()).catch(()=>{})}catch(e){}}}`
  },
  {
    name: "remember successful position-worklet preparation for the current audio context",
    // Observe readiness without replacing the original promise: failed sample
    // starts must retain their rejection, with no detached rejected promise.
    before: `GodotAudio.audioPositionWorkletPromise=ctx.audioWorklet.addModule(path);`,
    after: `GodotAudio.audioPositionWorkletReadyContext=null;const positionWorkletPromise=ctx.audioWorklet.addModule(path);GodotAudio.audioPositionWorkletPromise=positionWorkletPromise;positionWorkletPromise.then(()=>{if(GodotAudio.ctx===ctx&&GodotAudio.audioPositionWorkletPromise===positionWorkletPromise){GodotAudio.audioPositionWorkletReadyContext=ctx}},()=>{});`
  },
  {
    name: "start prepared WebAudio samples before subsequent game-frame work",
    // Awaiting an already resolved promise still postpones source.start until
    // after the current callback. The hot path must stay in the hit callback.
    before: `async connectPositionWorklet(start){await GodotAudio.audioPositionWorkletPromise;if(this.isCanceled){return}this._source.connect(this.getPositionWorklet());if(start){this.start()}}`,
    after: `async connectPositionWorklet(start){const ctx=GodotAudio.ctx;if(!ctx||this.isCanceled){return}if(GodotAudio.audioPositionWorkletReadyContext!==ctx){await GodotAudio.audioPositionWorkletPromise}if(this.isCanceled||GodotAudio.ctx!==ctx){return}this._source.connect(this.getPositionWorklet());if(start){this.start()}}`
  },
  {
    name: "preserve playback pitch when a WebAudio sample restarts",
    // A loop's ended callback replaces the source outside the game frame.
    // Restore its rate before start(), rather than waiting for the next frame.
    before: `_restart(){if(this._source!=null){this._source.disconnect()}this._source=GodotAudio.ctx.createBufferSource();this._source.buffer=this.getSample().getAudioBuffer();`,
    after: `_restart(){if(this._source!=null){this._source.disconnect()}this._source=GodotAudio.ctx.createBufferSource();this._source.buffer=this.getSample().getAudioBuffer();this._syncPlaybackRate();`
  },
  {
    name: "WASM callback rejection bridge",
    before: `if(Module["instantiateWasm"]){return new Promise((resolve,reject)=>{Module["instantiateWasm"](info,(inst,mod)=>{resolve(receiveInstance(inst,mod))})})}`,
    after: `if(Module["instantiateWasm"]){return new Promise((resolve,reject)=>{Promise.resolve(Module["instantiateWasm"](info,(inst,mod)=>{resolve(receiveInstance(inst,mod))})).catch(reject)})}`
  },
  {
    name: "streaming and fallback instantiation",
    before: `			'instantiateWasm': function (imports, onSuccess) {
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
`,
    after: `			'instantiateWasm': function (imports, onSuccess) {
				const source = r;
				r = null;
				function done(result) {
					onSuccess(result['instance'], result['module']);
				}
				if (typeof (WebAssembly.instantiateStreaming) !== 'undefined') {
					return WebAssembly.instantiateStreaming(Promise.resolve(source), imports).then(done);
				}
				return source.arrayBuffer().then(function (buffer) {
					return WebAssembly.instantiate(buffer, imports);
				}).then(done);
			},
`
  },
  {
    name: "engine initialization rejection chain",
    before: `				function doInit(promise) {
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
`,
    after: `				function doInit(promise) {
					// Care! Promise chaining is bogus with old emscripten versions.
					// This caused a regression with the Mono build (which uses an older emscripten version).
					// Make sure to test that when refactoring.
					return new Promise(function (resolve, reject) {
						promise.then(function (response) {
							let cloned = response.clone();
							if ((cloned.headers.get('content-type') || '').trim().toLowerCase() !== 'application/wasm') {
								cloned = new Response(cloned.body, { 'headers': [['content-type', 'application/wasm']] });
							}
							Godot(me.config.getModuleConfig(loadPath, cloned)).then(function (module) {
								const paths = me.config.persistentPaths;
								module['initFS'](paths).then(function (err) {
									if (err && err.name === 'StorageBlockedError') {
										throw err;
									}
									me.rtenv = module;
									if (me.config.unloadAfterInit) {
										Engine.unload();
									}
									resolve();
								}).catch(reject);
							}).catch(reject);
						}).catch(reject);
					});
				}
`
  },
  {
    name: "blocked IndexedDB upgrade",
    before: `getDB:(name,callback)=>{var db=IDBFS.dbs[name];if(db){return callback(null,db)}var req;try{req=IDBFS.indexedDB().open(name,IDBFS.DB_VERSION)}catch(e){return callback(e)}if(!req){return callback("Unable to connect to IndexedDB")}req.onupgradeneeded=e=>{var db=e.target.result;var transaction=e.target.transaction;var fileStore;if(db.objectStoreNames.contains(IDBFS.DB_STORE_NAME)){fileStore=transaction.objectStore(IDBFS.DB_STORE_NAME)}else{fileStore=db.createObjectStore(IDBFS.DB_STORE_NAME)}if(!fileStore.indexNames.contains("timestamp")){fileStore.createIndex("timestamp","timestamp",{unique:false})}};req.onsuccess=()=>{db=req.result;IDBFS.dbs[name]=db;callback(null,db)};req.onerror=e=>{callback(e.target.error);e.preventDefault()}}`,
    after: `getDB:(name,callback)=>{
  var db=IDBFS.dbs[name];
  if(db){return callback(null,db)}
  var req;
  try{req=IDBFS.indexedDB().open(name,IDBFS.DB_VERSION)}catch(e){return callback(e)}
  if(!req){return callback("Unable to connect to IndexedDB")}
  var settled=false;
  function finish(error,result){
    if(settled){return}
    settled=true;
    callback(error,result);
  }
  req.onblocked=()=>{
    var error=new Error("Close other Pip and Words game tabs, then try again to open your saved progress.");
    error.name="StorageBlockedError";
    finish(error);
  };
  req.onupgradeneeded=e=>{
    var transaction=e.target.transaction;
    if(settled){transaction.abort();return}
    var db=e.target.result;
    var fileStore;
    if(db.objectStoreNames.contains(IDBFS.DB_STORE_NAME)){
      fileStore=transaction.objectStore(IDBFS.DB_STORE_NAME);
    }else{
      fileStore=db.createObjectStore(IDBFS.DB_STORE_NAME);
    }
    if(!fileStore.indexNames.contains("timestamp")){
      fileStore.createIndex("timestamp","timestamp",{unique:false});
    }
  };
  req.onsuccess=()=>{
    db=req.result;
    if(settled){db.close();return}
    IDBFS.dbs[name]=db;
    finish(null,db);
  };
  req.onerror=e=>{e.preventDefault();finish(e.target.error)};
}`
  }
];

function patchWebEngine(source) {
  source = source.replaceAll('\r\n', '\n');
  for (const { name, before, after } of patches) {
    const start = source.indexOf(before);
    if (start < 0 || source.indexOf(before, start + before.length) !== -1) {
      throw new Error('Godot Web startup patch does not match exactly once: ' + name + '. Review the export template before shipping.');
    }
    source = source.slice(0, start) + after + source.slice(start + before.length);
  }
  return source;
}

module.exports = { patchWebEngine };
