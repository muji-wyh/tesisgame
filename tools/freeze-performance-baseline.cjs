const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const scopes = ['scripts', 'scenes', 'data', 'project.godot', 'words.json', 'phrases.json', 'curriculum.json', 'voice-prompts.json'];
const sharedDirectories = ['assets', '.godot', 'tests'];

function digest(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function exists(filename) {
  try { fs.lstatSync(filename); return true; } catch (error) {
    if (error.code === 'ENOENT') return false;
    throw error;
  }
}

function inside(parent, filename) {
  const relative = path.relative(parent, filename);
  return relative !== '' && relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative);
}

function refuseLinkedParents(repository, destination) {
  const relative = path.relative(repository, path.dirname(destination));
  let current = repository;
  for (const part of relative.split(path.sep)) {
    current = path.join(current, part);
    if (!exists(current)) continue;
    const stat = fs.lstatSync(current);
    if (stat.isSymbolicLink()) throw new Error(`Snapshot parents cannot be links or junctions: ${current}`);
    if (!stat.isDirectory()) throw new Error(`Snapshot parent is not a directory: ${current}`);
  }
}

function freezeBaseline({ repository = root, ref = 'HEAD', output } = {}) {
  repository = fs.realpathSync(repository);
  const git = args => execFileSync('git', args, { cwd: repository, windowsHide: true, maxBuffer: 64 * 1024 * 1024 });
  const commit = git(['rev-parse', '--verify', '--end-of-options', `${ref}^{commit}`]).toString('utf8').trim();
  if (!/^[a-f0-9]{40,64}$/.test(commit)) throw new Error('Git did not resolve a commit object');
  const resultsRoot = path.join(repository, 'build', 'performance');
  const destination = path.resolve(repository, output || path.join('build', 'performance', `baseline-${commit.slice(0, 12)}`));
  if (!inside(resultsRoot, destination)) throw new Error('Snapshot output must be a new directory inside build/performance');
  if (exists(destination)) throw new Error(`Refusing to replace existing snapshot destination: ${destination}`);
  refuseLinkedParents(repository, destination);

  // Resolve every input before creating the destination; an invalid ref or
  // unsupported tracked entry must never leave a misleading usable baseline.
  const records = git(['ls-tree', '-r', '-z', '--full-tree', commit, '--', ...scopes]).toString('utf8').split('\0').filter(Boolean);
  const blobs = records.map(record => {
    const match = /^(\d+) (\w+) ([a-f0-9]+)\t([\s\S]+)$/.exec(record);
    if (!match) throw new Error('Unexpected Git tree entry');
    const [, mode, type, oid, relative] = match;
    if (type !== 'blob' || !['100644', '100755'].includes(mode)) throw new Error(`Only regular tracked files can be frozen: ${relative}`);
    if (path.isAbsolute(relative) || relative.includes('\\') || relative.split('/').some(part => part === '..' || part === '.')) {
      throw new Error(`Unsafe tracked path: ${relative}`);
    }
    const filename = path.resolve(destination, ...relative.split('/'));
    if (!inside(destination, filename)) throw new Error(`Tracked path escapes snapshot: ${relative}`);
    const buffer = git(['show', `${commit}:${relative}`]);
    return { relative, mode, oid, buffer, sha256: digest(buffer) };
  });
  for (const required of scopes) {
    if (!blobs.some(blob => blob.relative === required || blob.relative.startsWith(`${required}/`))) {
      throw new Error(`Selected commit is missing required source: ${required}`);
    }
  }
  const linkKind = process.platform === 'win32' ? 'junction' : 'dir';
  const references = sharedDirectories.map(name => {
    const target = path.join(repository, name);
    if (!fs.statSync(target).isDirectory()) throw new Error(`Shared input is not a directory: ${target}`);
    return {
      name, target, resolved_target: fs.realpathSync(target), link_kind: linkKind,
      source: 'current workspace; shared, not frozen from the selected commit',
      mutable: true, directory_modified_at: fs.statSync(target).mtime.toISOString()
    };
  });
  const harnessReferences = ['tests/performance/main_scene_benchmark.gd', 'tests/godot/player_flow_fixture.gd'].map(relative => {
    const filename = path.join(repository, relative);
    if (!fs.statSync(filename).isFile()) throw new Error(`Shared harness is missing: ${relative}`);
    return { path: relative, sha256: digest(fs.readFileSync(filename)) };
  });
  const files = blobs.map(blob => ({ path: blob.relative, git_blob: blob.oid, mode: blob.mode, bytes: blob.buffer.length, sha256: blob.sha256 }));
  const manifest = {
    format: 1, created_at: new Date().toISOString(), requested_ref: ref, commit,
    repository, snapshot_directory: destination, scopes,
    source_tree_sha256: digest(Buffer.from(JSON.stringify(files), 'utf8')), files,
    shared_directories: references, shared_harness_at_creation: harnessReferences,
    limitation: 'Only the listed tracked source files are frozen. Assets, imported resources, and tests remain linked to the current workspace. Keep those inputs unchanged during a paired comparison; this is not an archive of licensed assets or engine imports.'
  };

  fs.mkdirSync(path.dirname(destination), { recursive: true });
  // Exclusive directory and file creation also reject a destination introduced
  // after preflight. On any later failure, preserve partial files for inspection.
  fs.mkdirSync(destination);
  for (const blob of blobs) {
    const filename = path.join(destination, ...blob.relative.split('/'));
    fs.mkdirSync(path.dirname(filename), { recursive: true });
    fs.writeFileSync(filename, blob.buffer, { flag: 'wx', mode: blob.mode === '100755' ? 0o755 : 0o644 });
  }
  for (const reference of references) fs.symlinkSync(reference.target, path.join(destination, reference.name), linkKind);
  fs.writeFileSync(path.join(destination, 'baseline-source.json'), `${JSON.stringify(manifest, null, 2)}\n`, { flag: 'wx' });
  return manifest;
}

function main() {
  const options = {};
  const args = process.argv.slice(2);
  while (args.length) {
    const argument = args.shift();
    if (argument === '--help') {
      console.log('node tools/freeze-performance-baseline.cjs [--ref HEAD] [--output build/performance/baseline-<commit>]\nCreates a new source snapshot. Existing destinations are always refused; no files are deleted or replaced.');
      return;
    }
    const [key, inline] = argument.replace(/^--/, '').split('=', 2);
    if (!argument.startsWith('--') || !['ref', 'output'].includes(key)) throw new Error(`Unknown option: ${argument}`);
    const value = inline ?? args.shift();
    if (!value || value.startsWith('--')) throw new Error(`Missing --${key} value`);
    options[key] = value;
  }
  const manifest = freezeBaseline(options);
  console.log(`Frozen ${manifest.files.length} files from ${manifest.commit}`);
  console.log(`Created ${manifest.snapshot_directory}`);
  console.log(`Source SHA-256: ${manifest.source_tree_sha256}`);
  console.log('Assets, imports, and the current benchmark harness remain shared directory links.');
}

if (require.main === module) main();
module.exports = { freezeBaseline };
