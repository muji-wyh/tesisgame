const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const base = __dirname;
const root = path.resolve(base, '../../../..');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const read = relative => JSON.parse(fs.readFileSync(path.join(base, relative)));
const evidence = relative => {
  const bytes = fs.readFileSync(path.join(base, relative));
  return { path: relative.replaceAll('\\', '/'), bytes: bytes.length, sha256: sha(bytes) };
};
const counter = read('source-record.json');
const parcel = read('parcel-source-record.json');
const sources = [...counter.files, ...parcel.files];
for (const item of sources) {
  if (sha(fs.readFileSync(path.join(base, item.retained_path))) !== item.sha256 || sha(fs.readFileSync(item.original_path)) !== item.sha256) throw new Error(`Source changed: ${item.retained_path}`);
}
for (const model of [...Object.values(counter.models), parcel.model]) {
  if (model.animations.length || model.skins.length) throw new Error('Unexpected animated source');
}
const layouts = ['straight', 'return', 'broad-return'].map(name => {
  const folder = `candidate-${name}`;
  const report = read(`${folder}/report.json`);
  if (report.failed !== 0 || report.checks.length !== 21 || report.checks.some(check => !check.passed)) throw new Error(`Native failure: ${name}`);
  if (evidence(`${folder}/counter.png`).sha256 !== report.candidate_sha256) throw new Error(`Candidate drift: ${name}`);
  return { layout: name, report, report_file: evidence(`${folder}/report.json`), log: evidence(`${folder}/render-r01.log`) };
});
const selected = layouts[2].report;
if (selected.source_instances.length !== 5 || selected.source_instances.filter(item => item.source.endsWith('/kitchenBar.glb')).length !== 4) throw new Error('Unexpected source composition');
const selectedFiles = read('selected-pixel-hashes.json');
for (const item of selectedFiles.files) {
  if (evidence(item.file).sha256 !== item.png_sha256) throw new Error(`Selected file drift: ${item.file}`);
}
const imageIntegrity = read('image-integrity.json');
if (imageIntegrity.failures) throw new Error('Image integrity failure');
const { loadProfessionalContent } = require(path.join(root, 'tools/validate-professional-content.cjs'));
const entry = loadProfessionalContent(root).lexemes.find(item => item.id === counter.sense_id);
if (entry.media.image.status !== 'pending' || entry.media.image.brief !== counter.approved_brief) throw new Error('Live image status or brief changed');
const originalViews = read('source-inspection/report.json');
const parcelViews = read('source-inspection-parcel/report.json');
if (originalViews.captures.length !== 6 || parcelViews.captures.length !== 4) throw new Error('Source inspection drift');
const collect = directory => fs.readdirSync(directory, { withFileTypes: true }).flatMap(item => item.isDirectory() ? collect(path.join(directory, item.name)) : [path.relative(base, path.join(directory, item.name)).replaceAll('\\', '/')]);
const receipt = {
  date: '2026-10-16',
  status: 'frozen_scratch_candidate_pending_independent_root_acceptance',
  reviewer: 'Codex retail_register_art (AI source and author visual review; not independent production acceptance)',
  sense_id: entry.id,
  definition: entry.definition,
  example: entry.example,
  approved_brief: entry.media.image.brief,
  sources: [
    { url: counter.source, creator: counter.creator, license: counter.license, local_version: counter.local_version, selected_asset: 'kitchenBar', status: 'Previously acquired original; four complete instances used', available_animations: [], record: evidence('source-record.json') },
    { url: parcel.source, creator: parcel.creator, license: parcel.license, local_version: parcel.local_version, selected_asset: 'box', status: 'Previously acquired original; one complete instance used', available_animations: [], record: evidence('parcel-source-record.json') }
  ],
  source_integrity: { original_and_retained_file_checks: sources.length, failures: 0, original_files_unchanged: true, source_geometry_modified: false, source_materials_modified: false, source_textures_modified: false, source_child_transforms_modified: false },
  selected_candidate: {
    file: evidence('candidate-broad-return/counter.png'),
    size: selected.candidate_size,
    decoded_cpu_gpu_bytes: selected.candidate_size[0] * selected.candidate_size[1] * 4 * 2,
    rgba_pixel_sha256: selectedFiles.files[0].rgba_pixel_sha256,
    source_instances: selected.source_instances,
    assembly_transform: 'The five source model roots are placed as recorded, then their common assembly root is recentered by the original composed mesh bounds. Exact calculation is retained in render-broad-return.gd.',
    camera: selected.camera,
    raw_size: selected.raw_size,
    focus_rectangle: selected.focus_rectangle,
    alpha_bounds: selected.alpha_bounds,
    crop: selected.crop,
    image_integrity: evidence('image-integrity.json'),
    rendering_script: evidence('render-broad-return.gd'),
    production_integration: false,
    independent_acceptance: null
  },
  native_validation: {
    invocations: 5,
    all_first_attempt_success: true,
    source_views: originalViews.captures.length + parcelViews.captures.length,
    source_reports: [evidence('source-inspection/report.json'), evidence('source-inspection-parcel/report.json')],
    source_logs: [evidence('source-inspection/render-r01.log'), evidence('source-inspection-parcel/render-r01.log')],
    layouts: layouts.map(item => ({ layout: item.layout, checks: item.report.checks.length, failures: item.report.failed, report: item.report_file, log: item.log })),
    selected_checks: selected.checks.length,
    selected_failures: selected.failed,
    measurements: selected.measurements,
    exact_selected_files_and_crop_pixel_hashes: selectedFiles.files,
    scope: 'Actual native WordCards with direct scratch ImageTexture assignment; not production Loader delivery, participant recognition, audio, curriculum or release acceptance.',
    native_slot_released_to_root_for_R09: true
  },
  author_visual_findings: {
    recommendation: 'Broad-return layout is the strongest candidate for independent root acceptance.',
    meaning: 'A broad raised pale surface and solid wood front dominate; the perpendicular return establishes a staff-side recess, and one small sealed parcel supports the service-counter example without indicating checkout, refund or pickup.',
    small_card: 'The selected image fills approximately 90.87 x 52 pixels in the 126 x 72 Match card. Main front panels, continuous top and inner return corner remain visible in both real matched and unmatched states.',
    limits: ['The near-white top loses some edge contrast against the white card.', 'The matched badge overlaps the far-right end of the return, while the main surface and inner corner remain visible.', 'No participant recognition study or separate service-function classification is claimed.'],
    unselected_sources: ['Furniture Kit cardboardBoxClosed has lifted flaps in actual source inspection and is not used.', 'Furniture Kit kitchenBarEnd was inspected but not used.'],
    unselected_layouts: ['Straight composition has less spatial evidence of the staff side.', 'Two-front-panel return layout renders only approximately 54.33 x 52 pixels at the minimum Match size; the selected broader composition provides a larger readable front.']
  },
  production_content_written_by_this_task: false,
  production_media_status_at_packaging: entry.media.image.status,
  render_dependencies: ['scripts/word_card.gd', 'scripts/game_data.gd', 'scripts/ui_style.gd', 'scripts/professional_catalog.gd', 'tools/run-godot.cjs'].map(relative => ({ path: relative, sha256: sha(fs.readFileSync(path.join(root, relative))) })),
  evidence_files: collect(base).filter(relative => relative !== 'review-receipt.json').sort().map(evidence)
};
fs.writeFileSync(path.join(base, 'review-receipt.json'), JSON.stringify(receipt, null, 2) + '\n', { flag: 'wx' });
console.log(JSON.stringify({ status: receipt.status, selected_sha256: receipt.selected_candidate.file.sha256, selected_bytes: receipt.selected_candidate.file.bytes, source_checks: sources.length, source_failures: 0, native_checks: layouts.reduce((sum, item) => sum + item.report.checks.length, 0), native_failures: 0, receipt_sha256: sha(fs.readFileSync(path.join(base, 'review-receipt.json'))) }));
