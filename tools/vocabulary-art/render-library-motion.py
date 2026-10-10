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


def cue(phase, poses):
    """A posed accent with explicit anticipation, emphasis and recovery beats."""
    for (start, first), (end, last) in zip(poses, poses[1:]):
        if phase <= end:
            progress = max(0, (phase - start) / (end - start))
            eased = progress * progress * (3 - 2 * progress)
            return first + (last - first) * eased
    return poses[-1][1]


ACCENT = [(0, 0), (.11, -.16), (.30, 1), (.42, 1), (.58, -.14), (.72, .18), (.88, 0), (1, 0)]
SWISH = [(0, 0), (.12, -.28), (.32, 1), (.53, -.40), (.71, .14), (.89, 0), (1, 0)]
LIFT = [(0, 0), (.13, 0), (.31, 1), (.41, .95), (.58, 0), (.72, .20), (.87, 0), (1, 0)]
GLIDE = [(0, 0), (.14, -.12), (.41, 1), (.55, .94), (.88, 0), (1, 0)]
CALM = [(0, 0), (.20, .15), (.46, 1), (.61, 1), (.92, 0), (1, 0)]


def rigid_frame(ax, ay, angle=0, dx=0, dy=0, zoom=1):
    """One undeformed camera/object transform; never stretch rigid artwork."""
    x, y = (X - ax - dx) / zoom, (Y - ay - dy) / zoom
    return ax + x * math.cos(angle) + y * math.sin(angle), ay - x * math.sin(angle) + y * math.cos(angle)


def frame(source, entry, index, profile_data):
    """Inverse-map source pixels; keep alpha attached to the original geometry."""
    phase = min(1, ((index / FRAMES + entry.get('phase', 0)) % 1) / profile_data['activeFraction'])
    # Stronger accents are followed by a readable rest, rather than a constant
    # sine-wave wiggle. Stable word offsets keep a page from moving in unison.
    accent, swish, lift = cue(phase, ACCENT), cue(phase, SWISH), cue(phase, LIFT)
    glide, calm = cue(phase, GLIDE), cue(phase, CALM)
    subdued = entry.get('motionTone') == 'calm'
    if subdued:
        accent, swish, lift = calm, .25 * calm, .25 * calm
    travel = entry.get('translationPx', profile_data['amplitude']['translationPx'])
    turn = math.radians(entry.get('rotationDeg', profile_data['amplitude']['rotationDeg']))
    camera_scale = profile_data.get('cameraScale', 0)
    framing_scale = entry.get('framingScale', profile_data.get('framingScale', 1))
    t = phase * math.tau
    ax, ay = [v * SIDE for v in entry['anchor']]
    rx, ry, rw, rh = [v * SIDE for v in entry['focalRect']]
    cx, cy = rx + rw / 2, ry + rh / 2
    focus = np.exp(-2 * (((X - cx) / max(rw, 12)) ** 2 + ((Y - cy) / max(rh, 12)) ** 2))
    feather = entry.get('edgeFeather', .15)
    edge_x = np.clip(np.minimum((X - rx) / max(rw * feather, 1), (rx + rw - X) / max(rw * feather, 1)), 0, 1)
    edge_y = np.clip(np.minimum((Y - ry) / max(rh * feather, 1), (ry + rh - Y) / max(rh * feather, 1)), 0, 1)
    focus *= edge_x ** 2 * (3 - 2 * edge_x) * edge_y ** 2 * (3 - 2 * edge_y)
    # A flat interior keeps the gesture readable at card size; only its perimeter
    # feathers into the stationary supports, rather than weakening every pixel.
    focus = np.minimum(1, focus * 1.6)
    upper = np.clip((ay - Y) / max(ay - ry, 20), 0, 1)
    u, v = X.copy(), Y.copy()
    profile = entry['profile']
    light = np.zeros_like(X)
    if profile in ['animal_breathe', 'soft_toy_sway']:
        # A curious perk and softer answering settle; feet never join the lift.
        u -= (travel * .72 * swish * upper ** 2 + (X - ax) * .022 * accent * upper) * focus
        v += travel * accent * upper * focus
    elif profile == 'aquatic_glide':
        # A dart, suspended glide and return, keeping fins and anatomy intact.
        u, v = rigid_frame(ax, ay, turn * swish, travel * glide, -travel * .40 * lift)
    elif profile == 'airborne_hover':
        u, v = rigid_frame(ax, ay, turn * swish, travel * .25 * swish, -travel * lift)
    elif profile == 'plant_sway':
        # Flexible tips follow the main breeze, while the stem stays planted.
        trailing = cue(max(0, phase - .07), SWISH)
        u -= travel * (swish * upper ** 1.5 + .24 * (trailing - swish) * upper ** 3) * focus
    elif profile == 'fabric_sway':
        flex = np.clip((Y - ay) / max(ry + rh - ay, 20), 0, 1)
        trailing = cue(max(0, phase - .08), SWISH)
        u -= travel * (swish * flex ** 1.5 + .32 * (trailing - swish) * flex ** 3) * focus
        light += .045 * accent * flex * focus
    elif profile == 'vehicle_roll':
        # The entire chassis stays rigid; the brief dip reads as suspension.
        settle = cue(phase, [(0, 0), (.17, .12), (.41, -.12), (.57, .50), (.70, -.12), (.86, 0), (1, 0)])
        u, v = rigid_frame(ax, ay, turn * swish, travel * glide, settle)
    elif profile == 'buoyant_rock':
        u, v = rigid_frame(ax, ay, turn * swish, 0, -travel * lift)
    elif profile == 'celestial_drift':
        u, v = rigid_frame(ax, ay, turn * swish, travel * .45 * swish, -travel * lift)
        light += .065 * max(0, accent) * focus
    elif profile == 'weather_flow':
        u -= travel * swish * focus
        v -= travel * .30 * lift * focus
        light += .035 * accent * focus
    elif profile == 'water_ripple':
        envelope = math.sin(math.pi * phase) ** 2
        u -= travel * np.sin(t * 1.4 + Y / 9) * envelope * focus
        v -= travel * .4 * np.sin(t * 1.4 + X / 16) * envelope * focus
        light += .060 * np.sin(t * 1.4 + Y / 8) * envelope * focus
    elif profile == 'flame_flicker':
        # Local flame response must not bend a fireplace or volcano silhouette.
        envelope = math.sin(math.pi * phase) ** 2
        u -= travel * np.sin(2 * t + upper * 2) * upper ** 1.5 * envelope * focus
        v += travel * math.sin(t * 2) * upper * envelope * focus
        light += .075 * math.sin(t * 2) * envelope * focus
    elif profile == 'elastic_bounce':
        # Only mapped soft toys compress. Two contacts give the hop a finish.
        compress = cue(phase, [(0, 0), (.12, 1), (.24, 0), (.43, 0), (.58, .70), (.68, 0), (.80, .18), (.9, 0), (1, 0)])
        local = entry.get('deformationRegion') == 'focal'
        effective_lift = lift * (.35 if local else 1)
        bend_u = ax + (X - ax) / (1 + .045 * compress - .008 * effective_lift)
        bend_v = ay + (Y - ay + travel * effective_lift) / (1 - .045 * compress + .008 * effective_lift)
        u, v = (X + (bend_u - X) * focus, Y + (bend_v - Y) * focus) if local else (bend_u, bend_v)
        if local:
            # Gelatin answers the contact with a supported side-to-side wobble;
            # the serving plate and the fixed lower rim never join the motion.
            u -= travel * swish * upper ** 1.5 * focus
    elif profile == 'supported_spin':
        # Small reversible angular inspection; do not claim continuous rotation.
        u, v = rigid_frame(ax, ay, turn * swish)
    elif profile == 'human_gesture':
        u -= travel * .65 * swish * upper ** 2 * focus
        v += travel * accent * upper * focus
    elif profile == 'face_expression':
        # Happy faces perk twice; sadness, fear and calm words stay restrained.
        # The actual eyes and mouth always remain the acquired expression.
        if subdued:
            calm_amplitude = profile_data['calmAmplitude']
            u, v = rigid_frame(ax, ay, math.radians(calm_amplitude['rotationDeg']) * calm,
                               0, -calm_amplitude['translationPx'] * calm)
        else:
            u, v = rigid_frame(ax, ay, turn * swish, 0, -travel * lift, framing_scale)
    elif profile == 'group_gesture':
        # The embrace or feeding contact is one connected, undeformed pose.
        u, v = rigid_frame(64, 64, turn * swish, 0, -travel * lift, framing_scale)
    elif profile == 'instrument_resonance':
        # A two-beat optical accent, without bending keys or claiming a key press.
        u, v = rigid_frame(64, 64, zoom=1 + camera_scale * max(0, accent))
        beam = np.exp(-((X - (18 + 92 * phase)) / 20) ** 2)
        light += .13 * beam * max(0, accent) * focus
    elif profile == 'diagram_focus':
        # Move the camera, not the teaching geometry: comparisons, arrows, counts
        # and family contact poses keep their exact relative positions and hues.
        u, v = rigid_frame(64, 64, zoom=1 + camera_scale * max(0, accent))
    elif profile == 'rigid_glint':
        if entry.get('presentation') == 'showcase':
            # A loose prop gives a small presentational nod, never a rubber squash.
            u, v = rigid_frame(64, 64, turn * swish, 0, -travel * lift, framing_scale)
        elif entry.get('presentation') == 'rock':
            u, v = rigid_frame(ax, ay, turn * swish)
        else:
            # Furniture, shells and scientific sources retain all supports and
            # anatomy. A closer camera view supplies the accent instead.
            u, v = rigid_frame(64, 64, zoom=1 + camera_scale * max(0, accent))
        beam = np.exp(-((X - (14 + 100 * phase) + .2 * (Y - 64)) / 17) ** 2)
        light += .14 * beam * max(0, accent)
    elif profile == 'scene_depth':
        # A complete photo/scene receives a lens move; no anatomy is deformed.
        u, v = rigid_frame(64, 64, travel * .003 * swish,
                           travel * .45 * glide, -travel * .25 * lift,
                           1 + camera_scale * (calm if subdued else max(0, accent)))
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
                tile = frame(pixels, entry, index, profile_data)
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
