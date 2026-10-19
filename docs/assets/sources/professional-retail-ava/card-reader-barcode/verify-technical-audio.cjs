'use strict';

// Read-only audio inspection; the sole output is a new immutable QA receipt.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const {loadProfessionalContent} = require('../../../../tools/validate-professional-content.cjs');
const {PROFILE, EDGE_TTS_VERSION, assertWave} = require('../../../../tools/generate-voices.cjs');
const root = path.resolve(__dirname, '../../../..');
const output = path.join(__dirname, 'technical-qa-r01.json');
assert.equal(fs.existsSync(output), false, 'Preserve the immutable QA receipt.');
const digest = value => crypto.createHash('sha256').update(value).digest('hex');
const jsonHash = value => digest(JSON.stringify(value));
const rawHash = file => digest(fs.readFileSync(file));
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const relative = file => path.relative(root, file).replaceAll('\\', '/');
const baselineFile = path.join(root, 'build/professional-english/continuation-validation-r14.json');
const rootCrosscheckFile = path.join(root, 'build/professional-english/retail-audio-review/counter-checkout-acquired-r01/delivery-r01/integration-receipt.json');
const priorVoiceReceiptFile = path.join(root, 'build/professional-english/retail-audio-review/retry-7.3.1/existing-catalog-preserved.json');
const voiceManifestFile = path.join(root, 'docs/assets/ava-voice.json');
const collectionManifestFile = path.join(root, 'docs/assets/jelly-collection-audio.json');
const presetFile = 'C:/Users/yaohuiwang/.codex/voice-presets/ava-sweet/preset.json';
const baseline = read(baselineFile), crosscheck = read(rootCrosscheckFile), preset = read(presetFile);
assert.equal(process.argv.length, 4);
assert.equal(process.argv[2], '--validation-sha256');
assert.match(process.argv[3], /^[a-f0-9]{64}$/);
assert.equal(rawHash(baselineFile), process.argv[3]);
const voiceManifest = read(voiceManifestFile), collectionManifest = read(collectionManifestFile), priorVoiceReceipt = read(priorVoiceReceiptFile);
const batchFile = path.join(__dirname, 'batch.json'), manifestFile = path.join(__dirname, 'manifest.json');
const batch = read(batchFile), manifest = read(manifestFile);
const checks = [], failures = [];
const check = (label, ok, details = null) => { checks.push({label, passed: Boolean(ok), ...(details === null ? {} : {details})}); if (!ok) failures.push(label); };
const stableFiles = [baselineFile, rootCrosscheckFile, priorVoiceReceiptFile, voiceManifestFile, collectionManifestFile, presetFile, batchFile, manifestFile, ...['tools/generate-professional-voices.cjs', 'tools/generate-voices.cjs', 'tools/edge-voice-batch.py', 'tools/voice-requirements.txt'].map(file => path.join(root, file))];
for (const term of batch.terms) stableFiles.push(term.source, term.wave, term.receipt);
const originalFileHashes = Object.fromEntries(stableFiles.map(file => [file, rawHash(file)]));
const initialRegistry = loadProfessionalContent(root);
const audioMetadata = data => ({lexemes: data.lexemes.map(entry => ({id: entry.id, audio: entry.media.audio})), expressions: data.expressions.map(entry => ({id: entry.id, audio: entry.media?.audio ?? null}))});
const initialAudioMetadata = audioMetadata(initialRegistry);
check('Production registry equals the completed R14 measured registry hash', jsonHash(initialRegistry) === baseline.registry_after_sha256);
check('The committed counter/checkout audio integration corroborates the same registry hash', crosscheck.after_registry_sha256 === baseline.registry_after_sha256);
check('Saved preset matches the exact approved profile', JSON.stringify(preset.synthesis) === JSON.stringify(PROFILE));
check('Saved preset specifies no postprocessing', preset.postprocessing === null);
check('Candidate client is the pinned edge-tts 7.3.1', EDGE_TTS_VERSION === '7.3.1' && manifest.edgeTtsVersion === EDGE_TTS_VERSION);
check('Candidate manifest matches approved voice/rate/pitch/volume', JSON.stringify(manifest.profile) === JSON.stringify(PROFILE));
check('Batch retains candidate-only and pending-listening status', batch.status === 'acquired_candidates_only' && batch.listening_review === 'pending');
check('The two selected exact senses are present', JSON.stringify(batch.terms.map(term => term.sense_id).sort()) === JSON.stringify(['barcode.product-code.n', 'card-reader.payment-device.n']));
check('R14 combined validation passed with no skipped tests', baseline.ok === true && baseline.runs.find(run => run.name === 'node').fail === 0 && baseline.runs.find(run => run.name === 'node').skipped === 0);
check('R14 measured inputs and registry stayed unchanged', baseline.registry_before_sha256 === baseline.registry_after_sha256 && baseline.changed_measured_inputs.length === 0 && JSON.stringify(baseline.before_input_sha256) === JSON.stringify(baseline.after_input_sha256));
const ffmpegVersion = spawnSync('ffmpeg', ['-version'], {encoding: 'utf8', windowsHide: true, timeout: 30000});
check('FFmpeg is available for independent decode comparison', !ffmpegVersion.error && ffmpegVersion.status === 0);

function waveDetails(bytes) {
  assertWave(bytes);
  let pcm = null, format = null;
  const chunks = [];
  for (let offset = 12; offset + 8 <= bytes.length;) {
    const id = bytes.toString('ascii', offset, offset + 4), size = bytes.readUInt32LE(offset + 4), start = offset + 8;
    chunks.push({id, bytes: size});
    if (id === 'fmt ') format = {encoding_code: bytes.readUInt16LE(start), channels: bytes.readUInt16LE(start + 2), sample_rate_hz: bytes.readUInt32LE(start + 4), byte_rate: bytes.readUInt32LE(start + 8), block_align: bytes.readUInt16LE(start + 12), bits_per_sample: bytes.readUInt16LE(start + 14)};
    if (id === 'data') pcm = bytes.subarray(start, start + size);
    offset = start + size + size % 2;
  }
  let peak = 0, minimum = 32767, maximum = -32768, clipped = 0, audible = 0, energy = 0;
  for (let offset = 0; offset < pcm.length; offset += 2) {
    const value = pcm.readInt16LE(offset);
    minimum = Math.min(minimum, value); maximum = Math.max(maximum, value); peak = Math.max(peak, Math.abs(value)); energy += value * value;
    if (value === -32768 || value === 32767) clipped++;
    if (Math.abs(value) >= 64) audible++;
  }
  const frames = pcm.length / format.block_align;
  return {pcm, report: {...format, chunks, data_bytes: pcm.length, sample_frames: frames, duration_seconds: frames / format.sample_rate_hz, minimum_sample: minimum, maximum_sample: maximum, peak_absolute_pcm16: peak, peak_fraction_full_scale: peak / 32768, peak_dbfs: 20 * Math.log10(peak / 32768), rms_dbfs: 20 * Math.log10(Math.sqrt(energy / frames) / 32768), full_scale_clipped_samples: clipped, audible_samples_at_abs64: audible, pcm_sha256: digest(pcm)}};
}

const candidateResults = [];
for (const term of batch.terms) {
  const receipt = read(term.receipt), wav = fs.readFileSync(term.wave), mp3 = fs.readFileSync(term.source), entry = initialRegistry.lexemes.find(item => item.id === term.sense_id);
  const parsed = waveDetails(wav);
  check(term.text + ': identity key binds exact recorded settings and text', term.key === jsonHash(term.identity));
  check(term.text + ': receipt and batch identities are exact', JSON.stringify(receipt.identity) === JSON.stringify(term.identity));
  check(term.text + ': receipt voice/rate/pitch/volume match saved preset', JSON.stringify(receipt.identity.profile) === JSON.stringify(preset.synthesis));
  check(term.text + ': provider and pinned client match', receipt.identity.provider === 'Microsoft Edge TTS' && receipt.identity.client.name === 'edge-tts' && receipt.identity.client.version === '7.3.1');
  check(term.text + ': synthesis is the exact selected term plus sentence stop', receipt.identity.synthesis_text === entry.text + '.');
  check(term.text + ': source MP3 hash matches receipt', digest(mp3) === receipt.source_mp3_sha256);
  check(term.text + ': WAV hash and byte count match receipt', digest(wav) === receipt.wav_sha256 && wav.length === receipt.bytes);
  check(term.text + ': full PCM16 mono 22050 Hz WAV passes format and audible-sample guard', parsed.report.encoding_code === 1 && parsed.report.channels === 1 && parsed.report.sample_rate_hz === 22050 && parsed.report.bits_per_sample === 16);
  check(term.text + ': zero full-scale clipped samples', parsed.report.full_scale_clipped_samples === 0);
  check(term.text + ': candidate has no listening approval or production integration', receipt.status === 'acquired_candidate' && receipt.pronunciation_and_listening_review === 'pending' && receipt.production_integrated === false);
  check(term.text + ': production audio metadata remains pending and unassigned', entry.media.audio.status === 'pending' && entry.media.audio.path === null && entry.media.audio.sha256 === null && entry.media.audio.voice_settings.postprocessing === false);
  const decodeArgs = ['-hide_banner', '-loglevel', 'error', '-nostdin', '-i', 'pipe:0', '-ac', '1', '-ar', '22050', '-c:a', 'pcm_s16le', '-map_metadata', '-1', '-fflags', '+bitexact', '-f', 's16le', 'pipe:1'];
  const decoded = spawnSync('ffmpeg', decodeArgs, {input: mp3, windowsHide: true, timeout: 30000, maxBuffer: 4 * 1024 * 1024});
  check(term.text + ': independent no-effects source decode completed', !decoded.error && decoded.status === 0, {exit_status: decoded.status, error: decoded.error?.message || null, stderr: decoded.stderr?.toString('utf8') || ''});
  const samePcm = !decoded.error && decoded.status === 0 && Buffer.compare(decoded.stdout, parsed.pcm) === 0;
  check(term.text + ': complete candidate PCM equals untrimmed no-effects MP3 decode/resample', samePcm);
  const probe = spawnSync('ffprobe', ['-v', 'error', '-show_streams', '-show_format', '-of', 'json', term.source], {encoding: 'utf8', windowsHide: true, timeout: 30000, maxBuffer: 1024 * 1024});
  check(term.text + ': source MP3 stream inspection succeeded', !probe.error && probe.status === 0);
  candidateResults.push({sense_id: term.sense_id, text: term.text, key: term.key, identity: receipt.identity, source_mp3: {path: relative(term.source), bytes: mp3.length, sha256: digest(mp3), stream_inspection: probe.status === 0 ? JSON.parse(probe.stdout) : null}, wav: {path: relative(term.wave), bytes: wav.length, sha256: digest(wav), ...parsed.report}, acquisition_receipt: {path: relative(term.receipt), raw_sha256: rawHash(term.receipt), json_sha256: jsonHash(receipt)}, exact_no_effects_redecode: {command: 'ffmpeg', args: decodeArgs, output: 'Raw PCM in memory only; no output file created', pcm_sha256: decoded.status === 0 ? digest(decoded.stdout) : null, equals_entire_candidate_pcm: samePcm}, original_production_audio_metadata: entry.media.audio});
}

check('Historical voice manifest is byte-identical to its earlier preservation receipt', rawHash(voiceManifestFile) === priorVoiceReceipt.manifest_sha256);
check('Historical manifest retains all 1888 unique recordings', voiceManifest.files.length === 1888 && new Set(voiceManifest.files.map(row => row.id)).size === 1888);
const historicRows = voiceManifest.files.map(row => {
  const file = path.join(root, row.path), exists = fs.existsSync(file), bytes = exists ? fs.readFileSync(file) : null;
  return {id: row.id, path: row.path, expected_sha256: row.sha256, actual_sha256: bytes ? digest(bytes) : null, expected_bytes: row.bytes, actual_bytes: bytes?.length ?? null, matches: Boolean(bytes && digest(bytes) === row.sha256 && bytes.length === row.bytes)};
});
check('All historical voice bytes match the established manifest', historicRows.every(row => row.matches));
const actualVoiceNames = fs.readdirSync(path.join(root, 'assets/audio/voice')).filter(name => name.endsWith('.wav')).sort();
check('Historical voice directory has exactly the inventoried WAV set', JSON.stringify(actualVoiceNames) === JSON.stringify(voiceManifest.files.map(row => path.basename(row.path)).sort()));
check('Existing collection manifest supplies seven sequential notes', collectionManifest.audio.length === 7 && collectionManifest.audio.map(row => row.degree).join(',') === 'do,re,mi,fa,sol,la,ti');
const collectionRows = collectionManifest.audio.map(row => {
  const bytes = fs.readFileSync(path.join(root, row.path));
  return {id: row.id, degree: row.degree, path: row.path, expected_sha256: row.sha256, actual_sha256: digest(bytes), bytes: bytes.length, matches: digest(bytes) === row.sha256};
});
check('All seven collection cues match their existing inventory', collectionRows.every(row => row.matches));
const collectionMaster = fs.readFileSync(path.join(root, collectionManifest.source.path));
check('Collection source master matches its existing inventory', digest(collectionMaster) === collectionManifest.source.sha256);
const integratedAudio = initialRegistry.lexemes.filter(entry => entry.media.audio.status === 'integrated').map(entry => {
  const audio = entry.media.audio, file = path.join(root, audio.path.slice(6)), actual = rawHash(file), fileRelative = relative(file);
  return {id: entry.id, path: fileRelative, metadata_sha256: audio.sha256, measured_r14_sha256: baseline.after_input_sha256[fileRelative] || null, actual_sha256: actual, matches: audio.sha256 === actual && baseline.after_input_sha256[fileRelative] === actual};
});
check('Existing integrated Professional audio bytes match metadata and the successful R14 measured byte inventory', integratedAudio.length === 10 && integratedAudio.every(row => row.matches));
check('No new Professional WAV was integrated', fs.readdirSync(path.join(root, 'professional-media')).filter(name => name.endsWith('.wav')).length === 10);

const finalRegistry = loadProfessionalContent(root);
check('Production registry is unchanged through QA and matches the R14 measured registry', jsonHash(finalRegistry) === jsonHash(initialRegistry) && jsonHash(finalRegistry) === baseline.registry_after_sha256);
check('All Professional lexeme/expression audio metadata is unchanged through QA', jsonHash(audioMetadata(finalRegistry)) === jsonHash(initialAudioMetadata));
const changedFiles = Object.entries(originalFileHashes).filter(([file, expected]) => rawHash(file) !== expected).map(([file]) => relative(file));
check('All candidate bytes, acquisition receipts, manifests, provenance and tools remain unchanged', changedFiles.length === 0, changedFiles);
const receipt = {schema: 1, recorded_at: new Date().toISOString(), status: failures.length ? 'technical_qa_failed' : 'technical_qa_passed_candidates_only', checks: checks.length, failures,
  boundaries: {listening_performed: false, pronunciation_approved: false, production_integrated: false, production_files_written: false, audio_generated: false, candidate_audio_modified: false, cloud_requests: 0, no_creative_postprocessing: candidateResults.every(row => row.exact_no_effects_redecode.equals_entire_candidate_pcm), voice_identity_evidence: 'Exact acquisition metadata and pinned client request code match the saved Ava profile. PCM inspection does not independently identify the remote speaker or establish pronunciation quality.', conversion_evidence: 'The full candidate PCM equals an independent decode/resample of the retained MP3 with no filters, trimming, normalization, pitch shift, rate effect or volume effect. Decode output exists in memory only.'},
  candidates: candidateResults,
  registry_preservation: {historical_baseline_file: relative(baselineFile), historical_baseline_raw_sha256: rawHash(baselineFile), historical_field: 'registry_after_sha256', historical_registry_json_sha256: baseline.registry_after_sha256, corroborating_file: relative(rootCrosscheckFile), corroborating_file_raw_sha256: rawHash(rootCrosscheckFile), before_json_sha256: jsonHash(initialRegistry), after_json_sha256: jsonHash(finalRegistry), audio_metadata_before_json_sha256: jsonHash(initialAudioMetadata), audio_metadata_after_json_sha256: jsonHash(audioMetadata(finalRegistry)), note: 'The candidates were acquired after successful R14 validation. The counter/checkout audio integration independently corroborates that registry. Direct byte checks establish preservation at these measured endpoints; no listening approval is inferred.'},
  historical_voices: {manifest: relative(voiceManifestFile), manifest_raw_sha256: rawHash(voiceManifestFile), earlier_preservation_receipt: relative(priorVoiceReceiptFile), earlier_receipt_raw_sha256: rawHash(priorVoiceReceiptFile), historical_manifest_sha256: priorVoiceReceipt.manifest_sha256, recordings: historicRows.length, matching_recordings: historicRows.filter(row => row.matches).length, regenerated: 0, files: historicRows},
  sequential_collection_audio: {manifest: relative(collectionManifestFile), manifest_raw_sha256: rawHash(collectionManifestFile), baseline_kind: 'Existing integrated per-note hash inventory; no newly invented historical manifest hash', files: collectionRows, source_master: {path: collectionManifest.source.path, expected_sha256: collectionManifest.source.sha256, actual_sha256: digest(collectionMaster)}, sequence_code_changed: false, runtime_or_listening_check: false},
  existing_integrated_professional_audio: integratedAudio,
  saved_preset: {path: presetFile, raw_sha256: rawHash(presetFile), id: preset.id, synthesis: preset.synthesis, postprocessing: preset.postprocessing},
  provenance_files_raw_sha256: Object.fromEntries(Object.entries(originalFileHashes).map(([file, value]) => [file.startsWith(root) ? relative(file) : file, value])),
  tools: {node: process.version, ffmpeg: ffmpegVersion.stdout?.split(/\r?\n/)[0] || null, verification_script_raw_sha256: rawHash(__filename)}, results: checks};
fs.writeFileSync(output, JSON.stringify(receipt, null, 2) + '\n', {flag: 'wx'});
console.log(JSON.stringify({status: receipt.status, checks: receipt.checks, failures, receipt_json_sha256: jsonHash(receipt), receipt_raw_sha256: rawHash(output), candidates: candidateResults.map(row => ({text: row.text, duration_seconds: row.wav.duration_seconds, peak_dbfs: row.wav.peak_dbfs, clipped_samples: row.wav.full_scale_clipped_samples, no_effects_pcm_match: row.exact_no_effects_redecode.equals_entire_candidate_pcm})), historical_voice_matches: historicRows.filter(row => row.matches).length, collection_matches: collectionRows.filter(row => row.matches).length, registry_after_json_sha256: jsonHash(finalRegistry)}, null, 2));
if (failures.length) process.exitCode = 1;
