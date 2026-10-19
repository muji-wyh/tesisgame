const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '../../..');
const { snapshotInputs, verifyBuildReceipt } = require(path.join(root, 'tools/web-build-receipt.cjs'));
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const logPath = path.join(__dirname, 'actual-web-build.log');
const resultPath = path.join(__dirname, 'actual-web-build-result.json');
if (fs.existsSync(logPath) || fs.existsSync(resultPath)) throw Error('This build witness is one-shot; preserve earlier execution.');
const oldReceipt = path.join(root, 'build/web-build.json');
if (fs.existsSync(oldReceipt)) fs.copyFileSync(oldReceipt, path.join(__dirname, 'prior-web-build.json'), fs.constants.COPYFILE_EXCL);
const before = snapshotInputs(root);
fs.writeFileSync(path.join(__dirname, 'build-inputs-before.json'), JSON.stringify(before, null, 2) + '\n', { flag: 'wx' });
const started = new Date().toISOString();
const logHandle = fs.openSync(logPath, 'wx');
const run = spawnSync(process.execPath, ['tools/build-web.cjs'], {
  cwd: root, windowsHide: true, encoding: 'utf8', stdio: ['ignore', logHandle, logHandle], timeout: 1800000
});
fs.closeSync(logHandle);
const log = fs.readFileSync(logPath, 'utf8');
const after = snapshotInputs(root);
fs.writeFileSync(path.join(__dirname, 'build-inputs-after.json'), JSON.stringify(after, null, 2) + '\n', { flag: 'wx' });
const oldMap = new Map(before.map(file => [file.path, `${file.bytes}:${file.sha256}`]));
const newMap = new Map(after.map(file => [file.path, `${file.bytes}:${file.sha256}`]));
let verification = null, verificationError = null;
if (run.status === 0 && !run.error) {
  try {
    const receipt = verifyBuildReceipt(root);
    const raw = fs.readFileSync(oldReceipt);
    fs.writeFileSync(path.join(__dirname, 'verified-web-build.json'), raw, { flag: 'wx' });
    verification = { receipt_sha256: digest(raw), source_inputs: receipt.sources.length,
      output_files: receipt.output.length, descriptor: receipt.professional_domain.release.descriptor,
      ready_modules: receipt.professional_domain.release.ready_modules,
      unavailable_modules: receipt.professional_domain.release.unavailable_modules,
      decoded_pack: receipt.professional_domain.decoded_pack,
      generated_inventory: receipt.professional_domain.native_proof.generated_inventory,
      retained_work_dir: receipt.professional_domain.release.work_dir };
  } catch (error) { verificationError = error.stack; }
}
const result = { schema_version: 1, started_at: started, finished_at: new Date().toISOString(),
  status: run.status, signal: run.signal, error: run.error?.message || null,
  log_sha256: digest(Buffer.from(log)), verification, verification_error: verificationError,
  changed_inputs: [...new Set([...oldMap.keys(), ...newMap.keys()])].filter(file => oldMap.get(file) !== newMap.get(file)).sort(),
  ok: run.status === 0 && !run.error && verification !== null && !verificationError,
  scope: 'Actual local Web build, native raw-PCK closure verification and persisted receipt verification. No deployment, browser gameplay or ready-module acceptance.' };
fs.writeFileSync(resultPath, JSON.stringify(result, null, 2) + '\n', { flag: 'wx' });
console.log(JSON.stringify(result));
process.exitCode = result.ok ? 0 : 1;
