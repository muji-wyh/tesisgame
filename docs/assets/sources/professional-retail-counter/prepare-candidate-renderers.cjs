const fs = require('node:fs');
const path = require('node:path');
const base = __dirname;
const original = fs.readFileSync(path.join(base, '../shelf-r01/render-candidate.gd'), 'utf8');
const root = 'res://build/professional-english/retail-term-art-review/counter-r01';

for (const layout of ['straight', 'return']) {
  let script = original;
  script = script.replace(/const BASE := .*/, `const BASE := "${root}/candidate-${layout}"`);
  script = script.replace(/const MODEL := .*/, `const MODEL := "${root}/source/original/kitchenBar.glb"\nconst PARCEL := "${root}/source/parcel/original/box.glb"`);
  script = script.replace('DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE))', 'assert(not FileAccess.file_exists(BASE + "/report.json"))\n\tDirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE))');
  script = script.replace('ambient_light_energy = 0.35', 'ambient_light_energy = 0.18');
  script = script.replace('light.light_energy = 0.65', 'light.light_energy = 0.38');
  const start = script.indexOf('\tvar document := GLTFDocument.new()');
  const end = script.indexOf('\tvar camera := Camera3D.new()', start);
  if (start < 0 || end < 0) throw new Error('Missing composition anchors');
  const composition = [
    '\tvar model := Node3D.new()',
    '\tviewport.add_child(model)',
    '\t_add_source(model, MODEL, Vector3(-0.43, 0, 0), 0.0, 1.0)',
    '\t_add_source(model, MODEL, Vector3(0, 0, 0), 0.0, 1.0)',
    ...(layout === 'return' ? ['\t_add_source(model, MODEL, Vector3(0.43, 0, -0.21), 90.0, 1.0)'] : []),
    '\t_add_source(model, PARCEL, Vector3(-0.12, 0.42, -0.105), -10.0, 0.16)',
    '\tvar bounds := _bounds(model)',
    '\tmodel.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)',
    ''
  ].join('\n');
  script = script.slice(0, start) + composition + script.slice(end);
  const size = layout === 'straight' ? 1.15 : 1.25;
  script = script.replace('camera.size = 0.98', `camera.size = ${size}`);
  script = script.replace('camera.position = Vector3(0.9, 1.8, 4)', 'camera.position = Vector3(-2.4, 2.6, 4)');
  script = script.replace('camera.look_at(Vector3(0, 0.66, 0))', 'camera.look_at(Vector3(0, 0.24, 0))');
  script = script.replace('var focus_raw := raw.get_region(Rect2i(0, 0, 768, 640))', 'var focus_raw := raw');
  script = script.replaceAll('/shelf.png', '/counter.png');
  script = script.replaceAll('"shelf-"', '"counter-"').replaceAll('shelf.storage-surface.n', 'counter.service-surface.n').replaceAll('"text": "shelf"', '"text": "counter"');
  script = script.replace('Shelf | actual WordCard at minimum observed sizes', `Counter (${layout}) | actual WordCard at minimum observed sizes`);
  script = script.replace('Scratch texture only. Source shelf and two boxes; close crop. No approval or production integration.', 'Scratch texture only. Original counter modules and one sealed parcel. No approval or integration.');
  script = script.replace('"position": [0.9, 1.8, 4], "target": [0, 0.66, 0], "orthographic_size": 0.98', `"position": [-2.4, 2.6, 4], "target": [0, 0.24, 0], "orthographic_size": ${size}`);
  script = script.replace('"ambient_energy": 0.35, "directional_energy": 0.65', '"ambient_energy": 0.18, "directional_energy": 0.38');
  script = script.replace('"focus_rectangle": [0, 0, 768, 640]', '"focus_rectangle": [0, 0, 768, 768]');
  script = script.replace('"omitted_source_nodes": ["carton", "carton2", "carton3", "carton4", "carton5", "carton6", "box3", "box4"], "preserved_visible_nodes": ["shelf-boxes", "box", "box2"]', `"layout": "${layout}", "source_instances": source_instances, "omitted_source_nodes": [], "preserved_visible_nodes": ["all source nodes"]`);
  script = script.replace('Shelf scratch candidate and actual WordCard QA: ', `Counter ${layout} scratch candidate and actual WordCard QA: `);
  script = script.replace('var checks: Array = []', 'var checks: Array = []\nvar source_instances: Array = []');
  script += '\nfunc _add_source(parent: Node3D, source: String, at: Vector3, yaw: float, uniform_scale: float) -> void:\n\tvar document := GLTFDocument.new()\n\tvar state := GLTFState.new()\n\tassert(document.append_from_file(ProjectSettings.globalize_path(source), state) == OK)\n\tvar model := document.generate_scene(state)\n\tparent.add_child(model)\n\tmodel.position = at\n\tmodel.rotation_degrees.y = yaw\n\tmodel.scale = Vector3.ONE * uniform_scale\n\tsource_instances.append({"source": source, "sha256": FileAccess.get_sha256(source), "root_position": [at.x, at.y, at.z], "root_y_rotation_degrees": yaw, "root_uniform_scale": uniform_scale, "geometry_materials_textures_and_child_transforms": "preserved"})\n';
  if (script.includes('shelf.storage') || script.includes('shelf.png') || script.includes('carton')) throw new Error('Unexpected shelf content');
  fs.writeFileSync(path.join(base, `render-${layout}.gd`), script, { flag: 'wx' });
}
console.log('Prepared two source-only counter layouts with actual minimum WordCard checks.');
