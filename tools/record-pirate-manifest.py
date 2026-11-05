"""Record measured Pirate provenance after optimization and Godot QA."""
from pathlib import Path
import argparse
import hashlib
import json
import struct


ROOT = Path(__file__).resolve().parents[1]


def record_file(path):
    raw = path.read_bytes()
    return {'path': str(path.relative_to(ROOT)).replace('\\', '/') if path.is_relative_to(ROOT)
            else str(path).replace('\\', '/'),
            'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


def glb_metrics(path):
    raw = path.read_bytes()
    length = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    surfaces = [p for mesh in doc['meshes'] for p in mesh['primitives']]
    return {'triangles': sum(doc['accessors'][p['indices']]['count'] // 3 for p in surfaces),
            'exported_vertices': sum(doc['accessors'][p['attributes']['POSITION']]['count'] for p in surfaces),
            'meshes': len(doc['meshes']), 'surfaces': len(surfaces), 'materials': len(doc['materials'])}


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path, default=Path('Q:/uwok/boss'))
args = parser.parse_args()
folder = ROOT / 'assets/pirate'
previous_path = folder / 'manifest.json'
previous = json.loads(previous_path.read_text(encoding='utf-8')) if previous_path.exists() else {}
audit = json.loads((folder / 'optimization-report.json').read_text(encoding='utf-8'))
if audit['status'] != 'passed':
    raise SystemExit('Complete the glTF audit before recording the manifest.')
designs = json.loads((folder / 'taunt-designs.json').read_text(encoding='utf-8'))
source_model = args.source / 'pirate-slime.glb'
model = folder / 'pirate-game.glb'
model_record = record_file(model)
if audit['sha256'] != model_record['sha256']:
    raise SystemExit('The final model no longer matches its passing glTF audit.')
morph_names = next(mesh['target_names'] for mesh in audit['meshes'] if mesh['target_names'])
if set(morph_names) != {'Bite_Open', 'Eye_Squint', 'Smile_Smirk', 'Tongue_Out'}:
    raise SystemExit('Retain all four authored expression morphs before recording the manifest.')
actual_taunts = [clip for clip in audit['clips'] if clip['name'].startswith('Taunt_')]
if len(actual_taunts) != 10 or not audit.get('taunts_distinct'):
    raise SystemExit('Verify ten distinct taunts before recording the manifest.')
if {clip['name'] for clip in actual_taunts} != {clip['name'] for clip in designs['clips']}:
    raise SystemExit('The taunt design inventory differs from the exported clips.')
baseline = {**record_file(source_model), **glb_metrics(source_model)}
optimized = {**model_record, **glb_metrics(model),
             'animations': [clip['name'] for clip in audit['clips']],
             'morph_targets': morph_names, 'front_axis': '+Z', 'up_axis': '+Y',
             'animation_origin': 'Locally authored object pivots, mouth and expression morphs; no skeletal bones',
             'renderer': 'Godot GL Compatibility',
             'actor': 'scripts/pirate_asset_actor.gd',
             'preview_scene': 'scenes/pirate_asset_preview.tscn',
             'import_hook': record_file(folder / 'pirate_import.gd'),
             'color_adapter': record_file(ROOT / 'scripts/pirate_asset_color.gd'),
             'color_encoding': 'glTF stores linear COLOR_0; Godot converts the vertex palette once to sRGB storage for Compatibility and enables vertex-color albedo'}
manifest = {
    'version': 1, 'character': 'Pirate / Captain Clover',
    'status': 'Integrated optimized Pirate replaces the live Jelly World Boss',
    'reference': {**record_file(args.source / 'reference.png'),
                  'creator': 'Unknown; supplied by the user',
                  'license': 'Not provided; no third-party reference license is claimed',
                  'acquisition': 'User-provided design reference copied locally'},
    'authoring': {'creator': 'Locally authored with Blender CLI at the user request',
                  'tool': 'Blender 5.2.2 LTS',
                  'editable_source': record_file(args.source / 'pirate-slime.blend'),
                  'animation_source': record_file(args.source / 'animation_library.py'),
                  'mouth_source': record_file(args.source / 'bite_geometry.py'),
                  'taunt_source': record_file(args.source / 'taunt_library.py')},
    'source_model': baseline, 'model': optimized,
    'optimization': {
        'bytes_reduction_percent': round(100 * (1 - optimized['bytes'] / baseline['bytes']), 2),
        'triangles_reduction_percent': round(100 * (1 - optimized['triangles'] / baseline['triangles']), 2),
        'method': 'Visible-pose proxy simplification, fixed barycentric morph transfer, motion-group mesh merge, vertex color finish consolidation and exact flat animation sample packing',
        'geometry_tool': record_file(ROOT / 'tools/optimize-pirate.py'),
        'packing_tool': record_file(ROOT / 'tools/pack-pirate-gltf.py'),
        'audit': 'assets/pirate/optimization-report.json'},
    'animation_contract': {
        'strength_codes': {'L': 'Light', 'M': 'Medium', 'P': 'Heavy'},
        'loop': 'Idle', 'one_shots': [clip['name'] for clip in audit['clips'] if clip['name'] != 'Idle'],
        'start_time_seconds': 0, 'reset': 'Every clip begins and finishes at rest with all four morph weights zero',
        'morph_reset': {name: 0 for name in morph_names},
        'rigid_hat': True, 'body_growth_peak': 1.7,
        'clip_timings': [{'name': clip['name'], 'duration_seconds': clip['duration_seconds']} for clip in audit['clips']],
        'taunt_count': len(actual_taunts), 'taunt_designs': record_file(folder / 'taunt-designs.json'),
        'taunts': [{**design, 'trajectory_sha256': next(clip['taunt_trajectory_sha256']
                    for clip in actual_taunts if clip['name'] == design['name'])}
                   for design in designs['clips']]},
}
render_report = ROOT / 'build/qa/pirate-asset/render-report.json'
rendered = json.loads(render_report.read_text(encoding='utf-8')) if render_report.exists() else {}
current_render = (rendered.get('model_sha256') == optimized['sha256'] and rendered.get('failures') == 0
                  and {pose['clip'] for pose in rendered.get('poses', [])} == set(optimized['animations']))
portrait = folder / 'pirate-portrait.png'
if portrait.exists():
    width, height = struct.unpack_from('>II', portrait.read_bytes(), 16)
    manifest['portrait'] = {**record_file(portrait), 'width': width, 'height': height,
                            'acquisition': 'Approved transparent Godot portrait retained while extending the action pack'}
    prior_portrait = previous.get('portrait', {})
    if prior_portrait.get('sha256') == manifest['portrait']['sha256']:
        manifest['portrait']['source_model_sha256'] = prior_portrait.get('source_model_sha256')
    verification = rendered.get('portrait', {})
    if current_render and verification.get('sha256') == manifest['portrait']['sha256']:
        manifest['portrait']['current_idle_verification'] = {
            'model_sha256': optimized['sha256'], 'path': verification.get('verification_path'),
            'sha256': verification.get('verification_sha256'), 'clip': 'Idle', 'time': .45}
        if verification.get('verification_sha256') == manifest['portrait']['sha256']:
            manifest['portrait']['source_model_sha256'] = optimized['sha256']
if current_render:
    manifest['validation'] = {'gltf_audit': 'passed', 'native_renderer': rendered['renderer'],
                              'native_pose_count': len(rendered['poses']),
                              'taunt_pose_count': sum(pose['clip'].startswith('Taunt_') for pose in rendered['poses']),
                              'additional_pose_count': len(rendered.get('extra_poses', [])),
                              'native_viewport': rendered['viewport'],
                              'mouth_closeup': rendered['mouth_closeup'],
                              'render_report': record_file(render_report)}
browser_report = ROOT / 'build/qa/pirate-asset/browser-report.json'
if browser_report.exists():
    browser = json.loads(browser_report.read_text(encoding='utf-8'))
    preview = Path(browser.get('offline_html', ''))
    if (browser.get('status') == 'passed' and browser.get('model_sha256') == optimized['sha256']
            and preview.is_file() and hashlib.sha256(preview.read_bytes()).hexdigest()
            == browser.get('offline_html_sha256')):
        manifest['offline_preview'] = {**record_file(preview), 'package_path': 'preview/pirate.html'}
        manifest.setdefault('validation', {}).update({
            'browser': 'passed', 'browser_report': record_file(browser_report),
            'browser_one_shots': len(browser['one_shot_playback']['results']),
            'mobile_viewport': browser['mobile']['viewport'],
            'mobile_scroll_preserved': browser['mobile']['scroll_preserved_after_click'],
            'reduced_motion_reset': browser['reduced_motion']['passed']})
(folder / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'bytes': optimized['bytes'], 'triangles': optimized['triangles'],
                  'reduction': manifest['optimization']['bytes_reduction_percent']}))
