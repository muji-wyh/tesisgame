#!/usr/bin/env node
'use strict';

// One-time source build; no global SDK installs, model files or generated
// binaries are committed. Node 18+, Python 3 and tar are required. On Windows,
// Git for Windows supplies sed for the upstream OpenFst build.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const { pipeline } = require('node:stream/promises');
const { Readable } = require('node:stream');

const ROOT = path.resolve(__dirname, '..');
const TOOLCHAIN = path.join(ROOT, 'build', 'multiplayer-toolchain');
const OUTPUT = path.join(ROOT, 'build', 'multiplayer');
const SHERPA_VERSION = '1.12.29';
const SDK_VERSION = '3.1.53';
const SDK_REVISION = 'a2b92777574c2feda07994cd4f1079a3dfc151f8';
const ASR_REVISION = '672fbf1b30579d6585301139bb363f42a0ad4a24';
const ASR_BASE = `https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26/resolve/${ASR_REVISION}`;
const BPE_SOURCE = { bytes: 244865, sha256: 'c53433de083c4a6ad12d034550ef22de68cec62c4f58932a7b6b8b2f1e743fa5', source: `${ASR_BASE}/bpe.model` };
const MODELS = [
  { id: 'encoder', file: 'encoder.onnx', bytes: 71082637, sha256: '0d072fd4ef956294ba9db9e9a71a541ac70659095ec4934c8453d8b2fe740187', source: `${ASR_BASE}/encoder-epoch-99-avg-1-chunk-16-left-64.int8.onnx` },
  { id: 'decoder', file: 'decoder.onnx', bytes: 2092621, sha256: '7bf787f90b194b307e5a4ad6a34fadb4e748304c35f78a8d66358a05b13ee6ef', source: `${ASR_BASE}/decoder-epoch-99-avg-1-chunk-16-left-64.onnx` },
  { id: 'joiner', file: 'joiner.onnx', bytes: 259335, sha256: 'd944208d660d67c8d72cd2acaeac971fa5ceb8c80e76c1968148846fedd6e297', source: `${ASR_BASE}/joiner-epoch-99-avg-1-chunk-16-left-64.int8.onnx` },
  { id: 'tokens', file: 'tokens.txt', bytes: 5048, sha256: '49e3c2646595fd907228b3c6787069658f67b17377c60aeb8619c4551b2316fb', source: `${ASR_BASE}/tokens.txt` },
  { id: 'bpe', file: 'bpe.vocab', bytes: 12590, sha256: 'f191a4935f668fa8cd8e607bcd378404f948321cd3134a5ea13d324ba921673d', source: BPE_SOURCE.source,
    derivation: { sourceSha256: BPE_SOURCE.sha256, tool: 'sentencepiece==0.2.1', format: 'UTF-8 piece<TAB>score<LF>, in model ID order' } },
  { id: 'speaker', file: 'speaker.onnx', bytes: 26530550, sha256: 'e9848563da86f263117134dfd7ad63c92355b37de492b55e325400c9d9c39012', source: 'https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/wespeaker_en_voxceleb_resnet34_LM.onnx' },
  { id: 'vad', file: 'silero_vad.onnx', bytes: 643854, sha256: '9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6', source: 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx' }
];
const MODEL_FILES = Object.fromEntries(MODELS.map((model) => [model.id, `/${model.file}`]));

function hash(file) { return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'); }
function matches(file, expected = {}) {
  return fs.existsSync(file) && (!expected.bytes || fs.statSync(file).size === expected.bytes) &&
    (!expected.sha256 || hash(file) === expected.sha256);
}

async function download(url, file, expected = {}) {
  if (matches(file, expected)) return;
  fs.mkdirSync(path.dirname(file), { recursive: true });
  console.log(`Downloading ${path.basename(file)}`);
  const partial = `${file}.part`;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(300000) });
      if (!response.ok) throw new Error(`HTTP ${response.status} for ${url}`);
      await pipeline(Readable.fromWeb(response.body), fs.createWriteStream(partial));
      if (!matches(partial, expected)) throw new Error(`Checksum or size mismatch for ${path.basename(file)}`);
      fs.renameSync(partial, file);
      return;
    } catch (error) {
      if (fs.existsSync(partial)) fs.unlinkSync(partial);
      if (attempt === 2) throw error;
    }
  }
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { cwd: ROOT, stdio: 'inherit', ...options });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${path.basename(command)} exited with ${result.status}`);
}

async function prepareBpeVocabulary(file, expected) {
  if (matches(file, expected)) return;
  const source = path.join(TOOLCHAIN, 'bpe.model');
  await download(BPE_SOURCE.source, source, BPE_SOURCE);
  const python = process.env.PYTHON || 'python';
  const pythonTools = path.join(TOOLCHAIN, 'python-tools');
  if (!fs.existsSync(path.join(pythonTools, 'sentencepiece-0.2.1.dist-info'))) {
    run(python, ['-m', 'pip', 'install', '--disable-pip-version-check', '--target', pythonTools, 'sentencepiece==0.2.1']);
  }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  // Export the model's actual unigram scores, not token IDs or guessed ranks.
  // This tiny derived asset is served dynamically; the build-only model and
  // SentencePiece package are never added to the browser download.
  run(python, ['-c', [
    'import pathlib, sys, sentencepiece as spm',
    'assert spm.__version__ == "0.2.1"',
    'model = spm.SentencePieceProcessor(model_file=sys.argv[1])',
    'text = "".join(f"{model.id_to_piece(i)}\\t{model.get_score(i)}\\n" for i in range(model.get_piece_size()))',
    'pathlib.Path(sys.argv[2]).write_text(text, encoding="utf-8", newline="\\n")'
  ].join('\n'), source, file], { env: { ...process.env, PYTHONPATH: [pythonTools, process.env.PYTHONPATH].filter(Boolean).join(path.delimiter) } });
  if (!matches(file, expected)) throw new Error('Checksum or size mismatch for generated BPE vocabulary.');
}

async function buildRuntime() {
  fs.mkdirSync(TOOLCHAIN, { recursive: true });
  const source = path.join(TOOLCHAIN, `sherpa-onnx-${SHERPA_VERSION}`);
  if (!fs.existsSync(path.join(source, 'CMakeLists.txt'))) {
    const archive = path.join(TOOLCHAIN, 'sherpa.zip');
    await download(`https://github.com/k2-fsa/sherpa-onnx/archive/refs/tags/v${SHERPA_VERSION}.zip`, archive, {
      sha256: '00934703536de1ae7463ade4365917153b94ecd090cd07a340c8b1b594166626'
    });
    run('tar', ['-xf', archive, '-C', TOOLCHAIN]);
  }
  // Upstream defaults this optional BPE worker pool to hardware_concurrency().
  // Single-thread WASM cannot create pthreads; per-stream hotwords call the
  // synchronous Encode overload, so a zero-sized pool is both valid and needed.
  const tokenizerSource = path.join(source, 'sherpa-onnx', 'csrc', 'online-recognizer-transducer-impl.h');
  const tokenizerText = fs.readFileSync(tokenizerSource, 'utf8');
  const tokenizerPrefix = `std::make_unique<ssentencepiece::Ssentencepiece>(${tokenizerText.includes('\r\n') ? '\r\n' : '\n'}            `;
  const originalTokenizer = `${tokenizerPrefix}config_.model_config.bpe_vocab);`;
  const wasmTokenizer = `${tokenizerPrefix}config_.model_config.bpe_vocab, 0);  // Voice Pop: synchronous WASM tokenizer.`;
  const originalCount = tokenizerText.split(originalTokenizer).length - 1;
  const patchedCount = tokenizerText.split(wasmTokenizer).length - 1;
  if (originalCount === 1 && patchedCount === 0) {
    fs.writeFileSync(tokenizerSource, tokenizerText.replace(originalTokenizer, wasmTokenizer));
  } else if (originalCount !== 0 || patchedCount !== 1) {
    throw new Error('The pinned sherpa BPE tokenizer source changed.');
  }

  const python = process.env.PYTHON || 'python';
  const sdk = process.env.VOICE_POP_EMSDK || path.join(TOOLCHAIN, 'emsdk-main');
  if (!fs.existsSync(path.join(sdk, 'emsdk.py'))) {
    if (process.env.VOICE_POP_EMSDK) throw new Error('VOICE_POP_EMSDK does not contain emsdk.py');
    const archive = path.join(TOOLCHAIN, 'emsdk-pinned.zip');
    await download(`https://github.com/emscripten-core/emsdk/archive/${SDK_REVISION}.zip`, archive);
    run('tar', ['-xf', archive, '-C', TOOLCHAIN]);
    const extracted = path.resolve(TOOLCHAIN, `emsdk-${SDK_REVISION}`);
    if (!extracted.startsWith(`${path.resolve(TOOLCHAIN)}${path.sep}`) || !path.resolve(sdk).startsWith(`${path.resolve(TOOLCHAIN)}${path.sep}`)) {
      throw new Error('SDK paths must stay inside the build toolchain directory.');
    }
    fs.renameSync(extracted, sdk);
  }
  const emscripten = path.join(sdk, 'upstream', 'emscripten');
  if (!fs.existsSync(path.join(emscripten, 'emcc.py'))) run(python, [path.join(sdk, 'emsdk.py'), 'install', SDK_VERSION]);
  if (!fs.existsSync(path.join(sdk, '.emscripten'))) run(python, [path.join(sdk, 'emsdk.py'), 'activate', SDK_VERSION]);

  const suffix = process.platform === 'win32' ? '.exe' : '';
  const pythonTools = path.join(TOOLCHAIN, 'python-tools');
  const cmake = path.join(pythonTools, 'cmake', 'data', 'bin', `cmake${suffix}`);
  const ninja = path.join(pythonTools, 'ninja', 'data', 'bin', `ninja${suffix}`);
  if (!fs.existsSync(cmake) || !fs.existsSync(ninja)) {
    run(python, ['-m', 'pip', 'install', '--disable-pip-version-check', '--target', pythonTools, 'cmake==3.29.6', 'ninja==1.11.1.1']);
  }
  const env = { ...process.env, EMSDK: sdk, EM_CONFIG: path.join(sdk, '.emscripten') };
  const gitTools = process.platform === 'win32' ? path.join(process.env.ProgramFiles || 'C:\\Program Files', 'Git', 'usr', 'bin') : '';
  env.PATH = [gitTools, emscripten, process.env.PATH].filter(Boolean).join(path.delimiter);
  const build = path.join(TOOLCHAIN, 'runtime-build');
  run(cmake, ['-S', path.join(__dirname, 'multiplayer-runtime'), '-B', build, '-G', 'Ninja',
    `-DCMAKE_MAKE_PROGRAM=${ninja}`, `-DCMAKE_TOOLCHAIN_FILE=${path.join(emscripten, 'cmake', 'Modules', 'Platform', 'Emscripten.cmake')}`,
    '-DCMAKE_BUILD_TYPE=Release', `-DSHERPA_SOURCE_DIR=${source}`], { env });
  run(cmake, ['--build', build, '--target', 'voice-pop-runtime', '--parallel', String(Math.min(6, os.availableParallelism?.() || 2))], { env });
  return build;
}

async function notices(output, build) {
  const texts = [
    'Voice Pop local speech runtime - third party notices',
    'sherpa-onnx 1.12.29 and streaming Zipformer English 2023-06-26 (icefall): Apache-2.0.',
    'WeSpeaker code: Apache-2.0. WeSpeaker ResNet34-LM model: CC-BY-4.0. Credit: WeSpeaker authors. Trained on VoxCeleb. Adaptation: sherpa-onnx metadata added to the model.',
    'WeSpeaker model attribution and source: https://huggingface.co/Wespeaker/wespeaker-voxceleb-resnet34-LM . License: https://creativecommons.org/licenses/by/4.0/ . No endorsement implied.',
    'Silero VAD: MIT. ONNX Runtime 1.17.1: MIT.',
    'Emscripten 3.1.53: MIT and University of Illinois/NCSA. Eigen 3.4.1: MPL-2.0.',
    'Model source URLs and fixed SHA256 hashes are recorded in manifest.json.',
    'Source adapter: tools/multiplayer-runtime. The build patches the sherpa-onnx online BPE tokenizer to use a zero-sized worker pool: hotwords encode synchronously in single-thread WebAssembly. The exact patch is in tools/prepare-multiplayer-runtime.cjs.'
  ];
  const local = [
    ['sherpa-onnx', path.join(TOOLCHAIN, `sherpa-onnx-${SHERPA_VERSION}`, 'LICENSE')],
    ['kaldi-native-fbank', path.join(build, '_deps', 'kaldi_native_fbank-src', 'LICENSE')],
    ['kaldi-decoder', path.join(build, '_deps', 'kaldi_decoder-src', 'LICENSE')],
    ['kaldifst', path.join(build, '_deps', 'kaldifst-src', 'LICENSE')],
    ['OpenFst', path.join(build, '_deps', 'openfst-src', 'COPYING')],
    ['KissFFT', path.join(build, '_deps', 'kissfft-src', 'COPYING')],
    ['simple-sentencepiece', path.join(build, '_deps', 'simple-sentencepiece-src', 'LICENSE')],
    ['nlohmann/json', path.join(build, '_deps', 'json-src', 'LICENSE.MIT')],
    ['Eigen', path.join(build, '_deps', 'eigen-src', 'COPYING.MPL2')],
    ['Emscripten', path.join(process.env.VOICE_POP_EMSDK || path.join(TOOLCHAIN, 'emsdk-main'), 'upstream', 'emscripten', 'LICENSE')]
  ];
  for (const [name, file] of local) {
    if (!fs.existsSync(file)) throw new Error(`Missing license for ${name}: ${file}`);
    texts.push(`\n${name}\n${fs.readFileSync(file, 'utf8')}`);
  }
  const remote = [
    ['ONNX Runtime', 'https://raw.githubusercontent.com/microsoft/onnxruntime/v1.17.1/LICENSE'],
    ['ONNX Runtime third-party notices', 'https://raw.githubusercontent.com/microsoft/onnxruntime/v1.17.1/ThirdPartyNotices.txt'],
    ['WeSpeaker', 'https://raw.githubusercontent.com/wenet-e2e/wespeaker/master/LICENSE'],
    ['WeSpeaker model CC-BY-4.0', 'https://creativecommons.org/licenses/by/4.0/legalcode.txt'],
    ['Silero VAD', 'https://raw.githubusercontent.com/snakers4/silero-vad/master/LICENSE'],
    ['Zipformer / icefall', 'https://raw.githubusercontent.com/k2-fsa/icefall/master/LICENSE']
  ];
  for (const [name, url] of remote) {
    const file = path.join(TOOLCHAIN, 'licenses', `${name.replace(/[^a-z0-9]/gi, '-')}.txt`);
    await download(url, file);
    texts.push(`\n${name}\nSource: ${url}\n${fs.readFileSync(file, 'utf8')}`);
  }
  fs.writeFileSync(path.join(output, 'THIRD_PARTY_NOTICES.txt'), texts.join('\n\n'));
}

async function prepareRuntime({ output = OUTPUT, skipBuild = false } = {}) {
  fs.mkdirSync(output, { recursive: true });
  for (const model of MODELS) {
    const file = path.join(output, 'models', model.file);
    if (model.id === 'bpe') await prepareBpeVocabulary(file, model);
    else await download(model.source, file, model);
  }
  const build = skipBuild ? path.join(TOOLCHAIN, 'runtime-build') : await buildRuntime();
  const assets = [];
  for (const extension of ['js', 'wasm']) {
    const file = `voice-pop-runtime.${extension}`;
    const built = [path.join(build, file), path.join(build, 'bin', file)].find(fs.existsSync);
    if (!built) throw new Error(`Missing ${file}; run without --skip-build.`);
    fs.copyFileSync(built, path.join(output, file));
    assets.push({ id: `runtime-${extension}`, url: file, bytes: fs.statSync(built).size, sha256: hash(built) });
  }
  assets.push(...MODELS.map((model) => ({ id: model.id, url: `models/${model.file}`, bytes: model.bytes, sha256: model.sha256, source: model.source,
    ...(model.derivation ? { derivation: model.derivation } : {}) })));
  await notices(output, build);
  const version = crypto.createHash('sha256').update(JSON.stringify(assets)).digest('hex').slice(0, 16);
  const manifest = {
    version: `voice-pop-local-v1-${version}`,
    sampleRate: 16000,
    runtime: { scriptId: 'runtime-js', wasmId: 'runtime-wasm', modelFiles: MODEL_FILES },
    assets,
    totalBytes: assets.reduce((sum, asset) => sum + asset.bytes, 0),
    notices: 'THIRD_PARTY_NOTICES.txt',
    models: { asr: 'Streaming Zipformer English 2023-06-26, chunk 16 / left 64', speaker: 'WeSpeaker en VoxCeleb ResNet34-LM', vad: 'Silero VAD' }
  };
  fs.writeFileSync(path.join(output, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
  console.log(`Local multiplayer ready to package: ${manifest.totalBytes.toLocaleString()} bytes in ${output}`);
  return manifest;
}

if (require.main === module) {
  const args = process.argv.slice(2);
  const outputIndex = args.indexOf('--output');
  prepareRuntime({ output: outputIndex >= 0 ? path.resolve(args[outputIndex + 1]) : OUTPUT, skipBuild: args.includes('--skip-build') })
    .catch((error) => { console.error(error.message); process.exitCode = 1; });
}
module.exports = { MODELS, MODEL_FILES, prepareRuntime, hash };
