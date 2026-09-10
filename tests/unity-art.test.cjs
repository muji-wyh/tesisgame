const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const python = process.env.UNITY_ART_PYTHON || 'python';
const helper = path.join(root, 'tools', 'unity-art-package.py');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const png = fs.readFileSync(path.join(root, 'assets/chests/royal/closed.png'));

function run(args) {
  return spawnSync(python, [helper, ...args], { encoding: 'utf8', cwd: root });
}

function fixture(t, pathname = 'Assets/Food/Apple.png', extra = []) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'word-buddies-unity-art-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const packagePath = path.join(dir, 'food.unitypackage');
  const guid = 'a'.repeat(32);
  const entries = [
    { name: `${guid}/pathname`, data: Buffer.from(pathname).toString('base64') },
    { name: `${guid}/asset`, data: png.toString('base64') },
    { name: `${guid}/asset.meta`, data: Buffer.from('untrusted metadata').toString('base64') },
    { name: `${'b'.repeat(32)}/pathname`, data: Buffer.from('Assets/Editor/DoNotRun.cs').toString('base64') },
    { name: `${'b'.repeat(32)}/asset`, data: Buffer.from('third party script').toString('base64') },
    ...extra
  ];
  const made = spawnSync(python, ['-c', `import base64,io,json,sys,tarfile
with tarfile.open(sys.argv[1], 'w:gz') as archive:
 for item in json.load(sys.stdin):
  data=base64.b64decode(item['data']); info=tarfile.TarInfo(item['name']); info.size=len(data)
  if item.get('link'): info.type=tarfile.SYMTYPE; info.linkname=item['link']; info.size=0
  archive.addfile(info, io.BytesIO(data))`, packagePath], { input: JSON.stringify(entries), encoding: 'utf8' });
  assert.equal(made.status, 0, made.stderr);
  const mapping = {
    package: { title: 'Test package', url: 'https://assetstore.unity.com/packages/2d/gui/icons/food-icons-pack-70018', version: 'test', sha256: hash(fs.readFileSync(packagePath)), license: 'Standard Unity Asset Store EULA' },
    images: [{ word: 'apple', source: pathname, sha256: hash(png) }]
  };
  const mappingPath = path.join(dir, 'mapping.json');
  fs.writeFileSync(mappingPath, JSON.stringify(mapping));
  return { dir, packagePath, mapping, mappingPath };
}

test('Unity art inventory and preparation retain selected PNGs without third-party code or metadata', t => {
  const f = fixture(t);
  const inspected = run(['inspect', f.packagePath]);
  assert.equal(inspected.status, 0, inspected.stderr);
  const inventory = JSON.parse(inspected.stdout);
  assert.equal(inventory.images.length, 1);
  assert.equal(inventory.images[0].source, 'Assets/Food/Apple.png');
  assert.equal(inventory.images[0].sha256, hash(png));
  const output = path.join(f.dir, 'prepared');
  const prepared = run(['prepare', f.packagePath, f.mappingPath, output, root]);
  assert.equal(prepared.status, 0, prepared.stderr);
  const result = JSON.parse(prepared.stdout);
  const listed = spawnSync(python, ['-c', `import json,sys,tarfile
with tarfile.open(sys.argv[1]) as archive:
 print(json.dumps({entry.name: archive.extractfile(entry).read().decode('utf-8', 'replace') for entry in archive if entry.isfile() and not entry.name.endswith('/asset')}))`, result.art_package], { encoding: 'utf8' });
  assert.equal(listed.status, 0, listed.stderr);
  const members = JSON.parse(listed.stdout);
  assert.equal(Object.keys(members).length, 2);
  assert.equal(members[`${'a'.repeat(32)}/pathname`], 'Assets/WordBuddiesImport/apple.png');
  assert.match(members[`${'a'.repeat(32)}/asset.meta`], /TextureImporter:/);
  assert.doesNotMatch(JSON.stringify(members), /DoNotRun|untrusted metadata/);
});

test('Unity art import refuses package/path/hash and vocabulary mismatches before producing output', t => {
  for (const unsafe of ['Assets/../escape.png', 'C:/outside.png', '/Assets/Food.png', 'Assets/Food/../../escape.png']) {
    const f = fixture(t, unsafe);
    const inspected = run(['inspect', f.packagePath]);
    assert.notEqual(inspected.status, 0, unsafe);
    assert.match(inspected.stderr, /unsafe.*path/i);
  }
  const f = fixture(t);
  for (const mutation of [m => { m.package.sha256 = '0'.repeat(64); }, m => { m.images[0].sha256 = '0'.repeat(64); }, m => { m.images[0].word = '../escape'; }, m => { m.images.push({ ...m.images[0] }); }, m => { m.images.push({ ...m.images[0], word: 'ball' }); }]) {
    const mapping = structuredClone(f.mapping);
    mutation(mapping);
    fs.writeFileSync(f.mappingPath, JSON.stringify(mapping));
    const output = path.join(f.dir, `rejected-${crypto.randomUUID()}`);
    const result = run(['prepare', f.packagePath, f.mappingPath, output, root]);
    assert.notEqual(result.status, 0);
    assert.equal(fs.existsSync(output), false, 'Invalid input must not create an art package');
  }
});

test('Unity archive rejects traversal, links and duplicate members', t => {
  for (const entry of [
    { name: '../escape', data: '' },
    { name: `${'c'.repeat(32)}/asset`, data: '', link: '../../outside' },
    { name: `${'a'.repeat(32)}/asset`, data: '' }
  ]) {
    const f = fixture(t, 'Assets/Food/Apple.png', [entry]);
    const result = run(['inspect', f.packagePath]);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /unsafe|duplicate/i);
  }
});

test('verification refuses absent or altered Unity outputs before updating Godot textures', t => {
  const f = fixture(t);
  const output = path.join(f.dir, 'prepared');
  assert.equal(run(['prepare', f.packagePath, f.mappingPath, output, root]).status, 0);
  const report = path.join(output, 'prepared.json');
  const staging = path.join(f.dir, 'staging');
  const destination = path.join(f.dir, 'godot');
  const imported = path.join(staging, 'Assets', 'WordBuddiesImport');
  fs.mkdirSync(imported, { recursive: true });
  assert.notEqual(run(['verify', report, staging, destination]).status, 0);
  assert.equal(fs.existsSync(destination), false);
  fs.writeFileSync(path.join(imported, 'apple.png'), 'wrong pixels');
  fs.writeFileSync(path.join(imported, 'apple.png.meta'), 'texture metadata');
  assert.notEqual(run(['verify', report, staging, destination]).status, 0);
  assert.equal(fs.existsSync(destination), false);
  fs.writeFileSync(path.join(imported, 'apple.png'), png);
  const verified = run(['verify', report, staging, destination]);
  assert.equal(verified.status, 0, verified.stderr);
  assert.deepEqual(fs.readFileSync(path.join(destination, 'assets/imported-unity/apple.png')), png);
  assert.equal(JSON.parse(verified.stdout).verified_imported_images, 1);
});

test('restricted Unity PNGs and import evidence stay outside tracked source', () => {
  const ignored = spawnSync('git', ['check-ignore', 'assets/imported-unity/apple.png', 'assets/imported-unity/apple.png.import', 'assets/imported-unity/manifest.json'], { encoding: 'utf8', cwd: root });
  assert.equal(ignored.status, 0);
  assert.equal(ignored.stdout.trim().split(/\r?\n/).length, 3);
});

function importedFixture(t) {
  const f = fixture(t, 'Assets/Food/Apple.png', [
    { name: `${'c'.repeat(32)}/pathname`, data: Buffer.from('Assets/Food/Pear.png').toString('base64') },
    { name: `${'c'.repeat(32)}/asset`, data: png.toString('base64') }
  ]);
  f.mapping.images.push({ word: 'pear', source: 'Assets/Food/Pear.png', sha256: hash(png) });
  fs.writeFileSync(f.mappingPath, JSON.stringify(f.mapping));
  const prepared = path.join(f.dir, 'prepared');
  assert.equal(run(['prepare', f.packagePath, f.mappingPath, prepared, root]).status, 0);
  const report = path.join(prepared, 'prepared.json');
  const staging = path.join(f.dir, 'staging');
  const imported = path.join(staging, 'Assets', 'WordBuddiesImport');
  fs.mkdirSync(imported, { recursive: true });
  for (const word of ['apple', 'pear']) {
    fs.writeFileSync(path.join(imported, `${word}.png`), png);
    fs.writeFileSync(path.join(imported, `${word}.png.meta`), 'texture metadata');
  }
  const destination = path.join(f.dir, 'godot');
  const verified = run(['verify', report, staging, destination]);
  assert.equal(verified.status, 0, verified.stderr);
  f.mapping.images.pop();
  fs.writeFileSync(f.mappingPath, JSON.stringify(f.mapping));
  const smaller = path.join(f.dir, 'smaller');
  assert.equal(run(['prepare', f.packagePath, f.mappingPath, smaller, root]).status, 0);
  return { ...f, report: path.join(smaller, 'prepared.json'), staging, imported, destination,
    overrides: path.join(destination, 'assets', 'imported-unity') };
}

test('a smaller verified mapping removes obsolete managed PNGs and Godot remaps only after validating all new art', t => {
  const f = importedFixture(t);
  const pear = path.join(f.overrides, 'pear.png');
  const remap = pear + '.import';
  fs.writeFileSync(remap, '[remap]\nimporter="texture"\n\n[deps]\nsource_file="res://assets/imported-unity/pear.png"\n');
  fs.writeFileSync(path.join(f.imported, 'apple.png'), 'damaged new import');
  assert.notEqual(run(['verify', f.report, f.staging, f.destination]).status, 0);
  assert.deepEqual(fs.readFileSync(pear), png);
  assert.equal(fs.existsSync(remap), true);
  fs.writeFileSync(path.join(f.imported, 'apple.png'), png);
  const verified = run(['verify', f.report, f.staging, f.destination]);
  assert.equal(verified.status, 0, verified.stderr);
  assert.equal(fs.existsSync(pear), false);
  assert.equal(fs.existsSync(remap), false);
  assert.deepEqual(fs.readFileSync(path.join(f.overrides, 'apple.png')), png);
  const manifest = JSON.parse(fs.readFileSync(path.join(f.overrides, 'manifest.json')));
  assert.deepEqual(manifest.images.map(image => image.word), ['apple']);
});

test('re-import refuses unrecognized or modified files without deleting existing artwork', t => {
  for (const [name, contents] of [['custom.png', 'user artwork'], ['pear.png', 'changed artwork'], ['pear.png.import', 'user file']]) {
    const f = importedFixture(t);
    const unexpected = path.join(f.overrides, name);
    fs.writeFileSync(unexpected, contents);
    const manifest = fs.readFileSync(path.join(f.overrides, 'manifest.json'));
    const result = run(['verify', f.report, f.staging, f.destination]);
    assert.notEqual(result.status, 0, name);
    assert.match(result.stderr, /unrecognized|modified|managed/i);
    assert.equal(fs.readFileSync(unexpected, 'utf8'), contents);
    assert.equal(fs.existsSync(path.join(f.overrides, 'pear.png')), true);
    assert.deepEqual(fs.readFileSync(path.join(f.overrides, 'manifest.json')), manifest);
  }
});

test('re-import refuses an override directory redirected outside the named game root', t => {
  const f = importedFixture(t);
  const outside = path.join(f.dir, 'outside');
  fs.renameSync(f.overrides, outside);
  fs.symlinkSync(outside, f.overrides, 'junction');
  const result = run(['verify', f.report, f.staging, f.destination]);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /redirect|outside|directory/i);
  assert.deepEqual(fs.readFileSync(path.join(outside, 'pear.png')), png);
});
