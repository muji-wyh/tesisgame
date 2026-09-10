// Godot 4.7.1 release export template fixes. Keep these anchors exact: an engine
// upgrade must be reviewed, not silently packaged with disconnected startup promises.
const patches = [
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
							const cloned = new Response(response.clone().body, { 'headers': [['content-type', 'application/wasm']] });
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
    var error=new Error("Close other Word Buddies game tabs, then try again to open your saved progress.");
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
