"""Animate acquired vocabulary illustrations without replacing their artwork.

The eight articulated Blender actions retain their authored timing. Other words
use reviewed, material-specific 2.5D illustration motion from an explicit map.
Run after prepare-library.cjs. Pillow and NumPy are required.
"""
import argparse
import hashlib
import json
import math
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / 'build/word-art-review'
OUT = REVIEW / 'library-motion'
SIDE, COLUMNS, FRAMES, FPS = 128, 8, 32, 12


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def digest(data):
    return hashlib.sha256(data).hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')


Y, X = np.mgrid[0:SIDE, 0:SIDE].astype(np.float32)


def frame(source, entry, index, active_fraction=1):
    """Inverse-map source pixels; keep alpha attached to the original geometry."""
    phase = min(1, ((index / FRAMES + entry.get('phase', 0)) % 1) / active_fraction)
    # Ease into and out of the movement; each family has a small settled hold.
    phase -= math.sin(phase * math.tau) / math.tau
    t = phase * math.tau
    s, c = math.sin(t), math.cos(t)
    ax, ay = [v * SIDE for v in entry['anchor']]
    rx, ry, rw, rh = [v * SIDE for v in entry['focalRect']]
    cx, cy = rx + rw / 2, ry + rh / 2
    focus = np.exp(-2 * (((X - cx) / max(rw, 12)) ** 2 + ((Y - cy) / max(rh, 12)) ** 2))
    edge_x = np.clip(np.minimum((X - rx) / max(rw * .15, 1), (rx + rw - X) / max(rw * .15, 1)), 0, 1)
    edge_y = np.clip(np.minimum((Y - ry) / max(rh * .15, 1), (ry + rh - Y) / max(rh * .15, 1)), 0, 1)
    focus *= edge_x ** 2 * (3 - 2 * edge_x) * edge_y ** 2 * (3 - 2 * edge_y)
    upper = np.clip((ay - Y) / max(ay - ry, 20), 0, 1)
    u, v = X.copy(), Y.copy()
    profile = entry['profile']
    light = np.zeros_like(X)
    if profile == 'animal_breathe':
        # Grounded feet, chest expansion and a small upper-body counter-lean.
        u -= (1.2 * s * upper ** 2 + (X - ax) * .018 * s * upper) * focus
        v += 1.3 * (1 - c) * upper * focus
    elif profile == 'aquatic_glide':
        u -= 2.4 * s
        v -= 1.2 * math.sin(t * 2) + 1.2 * np.sin((X - ax) / 45 + t) * focus
    elif profile == 'airborne_hover':
        angle = .018 * s
        u, v = ax + (X - ax) * math.cos(angle) + (Y - ay) * math.sin(angle), ay - (X - ax) * math.sin(angle) + (Y - ay) * math.cos(angle) - 2.4 * s
    elif profile == 'plant_sway':
        u -= 2.5 * np.sin(t + upper * .55) * upper ** 1.5
    elif profile == 'fabric_sway':
        flex = np.clip((Y - ay) / max(ry + rh - ay, 20), 0, 1)
        u -= 1.8 * np.sin(t + flex * .55) * flex ** 1.5 * focus
        light += .025 * np.sin(t + X / 18) * focus
    elif profile == 'vehicle_roll':
        u -= 3.2 * s
        v -= .65 * math.sin(2 * t) * focus
    elif profile == 'buoyant_rock':
        angle = .035 * s
        u, v = ax + (X - ax) * math.cos(angle) + (Y - ay) * math.sin(angle), ay - (X - ax) * math.sin(angle) + (Y - ay) * math.cos(angle) - 1.3 * c
    elif profile == 'celestial_drift':
        angle = .035 * s
        u, v = ax + (X - ax) * math.cos(angle) + (Y - ay) * math.sin(angle), ay - (X - ax) * math.sin(angle) + (Y - ay) * math.cos(angle) - 1.2 * s
        light += .035 * (.5 + .5 * math.sin(t + 1)) * focus
    elif profile == 'weather_flow':
        u -= 1.5 * np.sin(t + Y / 38) * focus
        v -= .7 * s * focus
        light += .025 * np.sin(t + Y / 32) * focus
    elif profile == 'water_ripple':
        u -= 1.3 * np.sin(t + Y / 9) * focus
        v -= .6 * np.sin(t + X / 16) * focus
        light += .035 * np.sin(t + Y / 8) * focus
    elif profile == 'flame_flicker':
        u -= 1.9 * np.sin(2 * t + upper * 2) * upper ** 1.5
        v += 1.5 * math.sin(t * 2) * upper
        light += .04 * math.sin(t * 2) * focus
    elif profile == 'elastic_bounce':
        # A soft toy's compression comes before the lift and resolves at contact.
        lift = max(0, s) ** 2
        compress = max(0, -s) ** 4
        bend_u = ax + (X - ax) / (1 + .035 * compress - .02 * lift)
        bend_v = ay + (Y - ay + 3.0 * lift) / (1 - .03 * compress + .02 * lift)
        u += (bend_u - X) * focus
        v += (bend_v - Y) * focus
    elif profile == 'supported_spin':
        # Small reversible angular inspection; do not claim continuous rotation.
        angle = .065 * s
        u, v = ax + (X - ax) * math.cos(angle) + (Y - ay) * math.sin(angle), ay - (X - ax) * math.sin(angle) + (Y - ay) * math.cos(angle)
    elif profile == 'human_gesture':
        u -= 1.25 * s * upper ** 2 * focus
        v += .9 * (1 - c) * upper * focus
    elif profile == 'face_expression':
        # A sourced expression nods gently; do not invent unlocated eyes or lips.
        angle = .025 * s
        u, v = ax + (X - ax) * math.cos(angle) + (Y - ay) * math.sin(angle), ay - (X - ax) * math.sin(angle) + (Y - ay) * math.cos(angle) - .65 * (1 - c)
        light += .018 * (1 - c) * focus
    elif profile == 'instrument_resonance':
        light += .065 * max(0, math.sin(t * 2)) ** 2 * focus
    elif profile == 'diagram_focus':
        # Semantic arrows/targets stay exactly fixed; a soft focus pass guides the eye.
        light += .085 * (.5 - .5 * c) * focus
    elif profile == 'rigid_glint':
        # Moving studio illumination preserves rigid silhouettes and contact points.
        beam = np.exp(-((X - (14 + 100 * phase) + .2 * (Y - 64)) / 17) ** 2)
        light += .105 * beam * math.sin(math.pi * phase) ** 2
    elif profile == 'scene_depth':
        # Photographs remain planar: a small camera drift, never rubber-sheet anatomy.
        zoom = 1 + .012 * (1 - c)
        u, v = 64 + (X - 64) / zoom - 1.1 * s, 64 + (Y - 64) / zoom - .55 * math.sin(2 * t)
    else:
        raise ValueError(f'Unsupported motion profile: {profile}')
    # Bilinear sampling in premultiplied alpha prevents dark transparent fringes.
    u = np.clip(u, 0, SIDE - 1.001)
    v = np.clip(v, 0, SIDE - 1.001)
    ix, iy = u.astype(np.int32), v.astype(np.int32)
    fx, fy = (u - ix)[..., None], (v - iy)[..., None]
    result = (source[iy, ix] * (1 - fx) + source[iy, ix + 1] * fx) * (1 - fy) + (source[iy + 1, ix] * (1 - fx) + source[iy + 1, ix + 1] * fx) * fy
    alpha = result[..., 3:4]
    rgb = np.divide(result[..., :3], np.maximum(alpha, .00001))
    # Lighter material response with a restrained lift; never a detached overlay.
    rgb += light[..., None] * (.55 + .45 * (1 - rgb))
    rgb = np.where(alpha > .001, rgb, 0)
    result = np.concatenate([np.clip(rgb, 0, 1), alpha], axis=2)
    return Image.fromarray(np.rint(result * 255).astype(np.uint8), 'RGBA')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ids', nargs='*')
    parser.add_argument('--integrate', action='store_true')
    args = parser.parse_args()
    mapping = read(ROOT / 'tools/vocabulary-art/library-motion-map.json')
    library = read(REVIEW / 'library/manifest.json')
    sources = {entry['id']: entry for entry in library['files']}
    clips = {entry['id']: entry for entry in read(ROOT / 'docs/assets/lv3-word-motion.json')['files']}
    expected = {word['id'] for word in read(ROOT / 'words.json') if word.get('image')}
    entries = {entry['id']: entry for entry in mapping['files']}
    if expected != entries.keys() or len(entries) != len(mapping['files']):
        raise ValueError('Motion map must explicitly cover every pictured word exactly once.')
    if args.integrate and args.ids:
        raise ValueError('Partial motion libraries cannot be integrated.')
    (OUT / 'atlases').mkdir(parents=True, exist_ok=True)
    previous_path = OUT / 'manifest.json'
    previous = {entry['id']: entry for entry in read(previous_path)['files']} if previous_path.exists() else {}
    renderer_sha = digest(Path(__file__).read_bytes())
    results = []
    for number, (word_id, entry) in enumerate(entries.items()):
        if args.ids and word_id not in args.ids:
            continue
        source = sources[word_id]
        target = OUT / 'atlases' / f'{word_id}.webp'
        profile_data = mapping['profiles'][entry['profile']]
        key = digest(json.dumps([entry, profile_data, source['sha256'], renderer_sha], sort_keys=True).encode())
        if entry['profile'] == 'authored_clip':
            clip = clips[word_id]
            authored_bytes = (ROOT / clip['path']).read_bytes()
            if len(authored_bytes) != clip['bytes'] or digest(authored_bytes) != clip['sha256']:
                raise ValueError(f'Unreviewed authored animation bytes: {word_id}')
            shutil.copyfile(ROOT / clip['path'], target)
            record = dict(clip, sourceSha256=source['sha256'], cacheKey=key, profile=entry['profile'])
        elif previous.get(word_id, {}).get('cacheKey') == key and target.exists() and digest(target.read_bytes()) == previous[word_id]['sha256']:
            record = previous[word_id]
        else:
            picture_path = REVIEW / 'library/pictures' / f'{word_id}.webp'
            if digest(picture_path.read_bytes()) != source['sha256']:
                raise ValueError(f'Unreviewed picture bytes: {word_id}')
            picture = Image.open(picture_path).convert('RGBA').resize((SIDE, SIDE), Image.Resampling.LANCZOS)
            pixels = np.asarray(picture, dtype=np.float32) / 255
            pixels[..., :3] *= pixels[..., 3:4]
            sheet = Image.new('RGBA', (SIDE * COLUMNS, SIDE * math.ceil(FRAMES / COLUMNS)))
            frame_hashes, margins = [], []
            for index in range(FRAMES):
                tile = frame(pixels, entry, index, profile_data.get('activeFraction', 1))
                frame_hashes.append(digest(tile.tobytes()))
                mask = np.asarray(tile)[..., 3] >= 200
                yy, xx = np.where(mask)
                if len(xx) == 0:
                    raise ValueError(f'Empty animation frame: {word_id}/{index}')
                margins.append(int(min(xx.min(), yy.min(), SIDE - 1 - xx.max(), SIDE - 1 - yy.max())))
                sheet.paste(tile, (index % COLUMNS * SIDE, index // COLUMNS * SIDE))
            if len(set(frame_hashes)) < 8 or min(margins) < 1:
                raise ValueError(f'Static or clipped animation: {word_id}, frames={len(set(frame_hashes))}, margin={min(margins)}')
            sheet.save(target, 'WEBP', quality=88, method=4, exact=True)
            record = dict(id=word_id, frames=FRAMES, fps=FPS, frameSide=SIDE, columns=COLUMNS,
                          posterFrame=0, profile=entry['profile'], sourceSha256=source['sha256'], cacheKey=key,
                          uniqueFrames=len(set(frame_hashes)), minimumOpaqueMargin=min(margins))
        data = target.read_bytes()
        record.update(path=f'assets/images/word-motion/{word_id}.webp', bytes=len(data), sha256=digest(data),
                      sourceRecord='docs/assets/word-library.json', creator=source['source']['creator'],
                      license=source['source']['license'], adaptation='Grow with Pip: ' + mapping['profiles'][entry['profile']]['intent'])
        results.append(record)
        if len(results) % 50 == 0:
            checkpoint = dict(previous)
            checkpoint.update({row['id']: row for row in results})
            write(previous_path, dict(schema=1, count=len(checkpoint), status='Local motion review', files=list(checkpoint.values())))
            print(f'Animated {len(results)} / {len(entries)}', flush=True)
    if args.ids:
        for record in results:
            previous[record['id']] = record
        results = list(previous.values())
    manifest = dict(schema=1, count=len(results), status='Local motion review', files=results)
    write(previous_path, manifest)
    print(json.dumps(dict(count=len(results), bytes=sum(row['bytes'] for row in results))), flush=True)
    if args.integrate:
        if {row['id'] for row in results} != expected:
            raise ValueError('Incomplete animated vocabulary cannot ship.')
        for record in results:
            shutil.copyfile(OUT / 'atlases' / f"{record['id']}.webp", ROOT / record['path'])
            record.pop('cacheKey', None)
        manifest['status'] = 'Integrated'
        write(ROOT / 'docs/assets/word-library-motion.json', manifest)
        runtime_keys = ['id', 'path', 'frames', 'fps', 'frameSide', 'columns', 'posterFrame']
        write(ROOT / 'data/word-motion.json', dict(schema=1, files=[{key: row[key] for key in runtime_keys} for row in results]))


if __name__ == '__main__':
    main()
