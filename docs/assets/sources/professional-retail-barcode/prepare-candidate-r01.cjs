'use strict';
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const sharp = require('C:/Users/yaohuiwang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const base = __dirname, out = path.join(base, 'candidate-r01');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const write = (name, bytes) => fs.writeFileSync(path.join(out, name), bytes, {flag: 'wx'});
async function main() {
  fs.mkdirSync(out);
  const svg = fs.readFileSync(path.join(base, 'barcode.svg'), 'utf8');
  assert.equal(hash(svg), '0dc559c59bd63c4e812e7f3e31562a533cf59603d93c299218fe07eece297303');
  const crop = svg.replace('viewBox="0 0 300 300"', 'viewBox="92 79 173 88"');
  assert.notEqual(crop, svg);
  write('label-crop.svg', crop);
  const png = await sharp(Buffer.from(crop), {density: 288}).resize(692, 352).png().toBuffer();
  write('label.png', png);
  const origin = 'build/professional-english/retail-term-art-review/counter-r01/render-broad-return.gd';
  let gd = fs.readFileSync(origin, 'utf8');
  const replace = (before, after) => {assert.equal(gd.split(before).length - 1, 1, before.slice(0, 90));gd = gd.replace(before, after);};
  replace('const BASE := "res://build/professional-english/retail-term-art-review/counter-r01/candidate-broad-return"', 'const BASE := "res://build/professional-english/retail-term-art-review/barcode-source-acquisition-r01/candidate-r01"');
  replace('const MODEL := "res://build/professional-english/retail-term-art-review/counter-r01/source/original/kitchenBar.glb"\nconst PARCEL := "res://build/professional-english/retail-term-art-review/counter-r01/source/parcel/original/box.glb"', 'const MODEL := "res://build/professional-english/retail-term-art-review/counter-r01/source/parcel/original/box.glb"');
  replace('viewport.size = Vector2i(768, 768)', 'viewport.size = Vector2i(768, 440)');
  const first = gd.indexOf('\t_add_source(model, MODEL, Vector3(-0.645');
  const end = gd.indexOf('\tvar bounds := _bounds(model)', first);
  assert.ok(first > 0 && end > first);
  gd = gd.slice(0, first) + '\t_add_source(model, MODEL, Vector3.ZERO, 0.0, 1.0)\n' + gd.slice(end);
  replace('\tvar camera := Camera3D.new()', [
    '\t# Display a crop of the sourced netalloy artwork on the original parcel face.',
    '\tvar label := MeshInstance3D.new()',
    '\tvar quad := QuadMesh.new()',
    '\tquad.size = Vector2(0.61, 0.61 * 88.0 / 173.0)',
    '\tlabel.mesh = quad',
    '\tvar label_material := StandardMaterial3D.new()',
    '\tlabel_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED',
    '\tlabel_material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(BASE + "/label.png"))',
    '\tlabel_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR',
    '\tlabel.material_override = label_material',
    '\tlabel.position = Vector3(0, 0.46, 0.359)',
    '\tmodel.add_child(label)',
    '\tvar camera := Camera3D.new()'
  ].join('\n'));
  replace('camera.size = 1.55', 'camera.size = 0.48');
  replace('camera.position = Vector3(-1.1, 1.8, 4)', 'camera.position = Vector3(0.28, 0.76, 3)');
  replace('camera.look_at(Vector3(0, 0.24, 0))', 'camera.look_at(Vector3(0, 0.48, 0))');
  replace('_check(raw.get_pixel(0, 0).a == 0.0, "Render background has alpha zero")', '_check(raw.get_size() == Vector2i(768, 440), "Exact intentional close-up framing")');
  replace('var crop := used.grow(16).intersection(Rect2i(Vector2i.ZERO, focus_raw.get_size()))', 'var crop := Rect2i(Vector2i.ZERO, focus_raw.get_size())');
  gd = gd.replaceAll('/counter.png', '/barcode.png').replaceAll('counter.service-surface.n', 'barcode.product-code.n').replaceAll('"counter-"', '"barcode-"').replaceAll('"text": "counter"', '"text": "barcode"');
  replace('Counter (broad return) | actual WordCard at minimum observed sizes', 'Barcode on package | actual WordCard at minimum sizes');
  replace('Scratch texture only. Original counter modules and one sealed parcel. No approval or integration.', 'Sourced barcode on original Kenney parcel; intentional close-up. Scratch only.');
  replace('"position": [-1.1, 1.8, 4], "target": [0, 0.24, 0], "orthographic_size": 1.55', '"position": [0.28, 0.76, 3], "target": [0, 0.48, 0], "orthographic_size": 0.48');
  replace('"raw_size": [768, 768], "focus_rectangle": [0, 0, 768, 768], "layout": "broad-return"', '"raw_size": [768, 440], "focus_rectangle": [0, 0, 768, 440], "layout": "intentional-package-edge-closeup", "label_texture_sha256": FileAccess.get_sha256(BASE + "/label.png"), "label_size": [0.61, 0.61 * 88.0 / 173.0], "label_position": [0, 0.46, 0.359]');
  replace('Counter broad return scratch candidate and actual WordCard QA:', 'Barcode close-up scratch candidate and actual WordCard QA:');
  write('render.gd', gd);
  write('preparation.json', JSON.stringify({schema:1,status:'source_candidate_prepared_not_rendered',source_svg_sha256:hash(svg),label_svg_sha256:hash(crop),label_png_sha256:hash(png),renderer_origin:origin,renderer_origin_sha256:hash(fs.readFileSync(origin)),renderer_sha256:hash(gd),original_parcel_sha256:'b773815c791d2708a2a70f1a9bb6d197d7211269ad96e273f9e364ea536c1b18',adaptations:['Crop source graphic to its existing barcode label, retaining all bars and spaces.','Apply sourced label to an unchanged complete Kenney parcel via a planar artwork surface.','Intentional close-up framing shows the package edge; no source geometry is deleted or distorted.'],source_visual_review:'Root inspected full source barcode and existing original parcel front render. Label retained for candidate exploration; black source backdrop not selected.',claims_excluded:['production integration','valid machine-readable encoding','real product identity','human recognition study'],production_changed:false},null,2)+'\n');
  console.log(JSON.stringify({renderer: path.join(out,'render.gd'),sha256:hash(gd),label_png_sha256:hash(png)}));
}
main().catch(e=>{console.error(e);process.exitCode=1;});
