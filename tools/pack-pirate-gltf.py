"""Pack the authored Pirate GLB for Godot without changing its motion.

Only exact constant samples and interior samples of exact flat runs are
removed. Quaternion signs, spinning samples, morph values and reset channels
are retained. The exporter frame-one offset is shifted to a common clip zero.
No third-party packages are required.

Example:
    python tools/pack-pirate-gltf.py --input build/pirate/pirate-game.raw.glb \
        --output assets/pirate/pirate-game.glb
"""
import argparse
from bisect import bisect_right
import hashlib
import json
import math
import struct
from pathlib import Path


BASE_CLIPS = (
    'Idle', 'Attack_L', 'Attack_M', 'Attack_P', 'Hit_L', 'Hit_M', 'Hit_P',
    'Ultimate_TidalRush', 'Ultimate_CrescentSpin', 'Ultimate_CaptainsDrop',
    'Special_GiantRam', 'Special_BigBite',
)
TAUNTS = (
    'Taunt_HatTip', 'Taunt_BellyLaugh', 'Taunt_SideEye', 'Taunt_NopeWag',
    'Taunt_Peekaboo', 'Taunt_MockBow', 'Taunt_Swagger', 'Taunt_TongueTease',
    'Taunt_VictoryLap', 'Taunt_FakeSleep',
)
CLIPS = BASE_CLIPS + TAUNTS
MORPHS = ('Bite_Open', 'Eye_Squint', 'Smile_Smirk', 'Tongue_Out')
DURATIONS = {
    'Idle': 3, 'Attack_L': .65, 'Attack_M': 1.05, 'Attack_P': 1.55,
    'Hit_L': .5, 'Hit_M': .9, 'Hit_P': 1.45,
    'Ultimate_TidalRush': 2.25, 'Ultimate_CrescentSpin': 2.25,
    'Ultimate_CaptainsDrop': 2.5, 'Special_GiantRam': 2.3, 'Special_BigBite': 1.6,
    'Taunt_HatTip': 1.5, 'Taunt_BellyLaugh': 2.1, 'Taunt_SideEye': 1.7,
    'Taunt_NopeWag': 1.5, 'Taunt_Peekaboo': 2, 'Taunt_MockBow': 2,
    'Taunt_Swagger': 2.1, 'Taunt_TongueTease': 1.8,
    'Taunt_VictoryLap': 2.5, 'Taunt_FakeSleep': 2.6,
}
WIDTH = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4,
         'MAT2': 4, 'MAT3': 9, 'MAT4': 16}
COMPONENT = {5120: ('b', 1), 5121: ('B', 1), 5122: ('h', 2),
             5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4)}
LIMITS = {'triangles': 12000, 'surfaces': 6, 'materials': 6,
          'meshes': 2, 'bytes_exclusive': 2000000}


def read_glb(path):
    raw = Path(path).read_bytes()
    if len(raw) < 20 or struct.unpack_from('<III', raw) != (0x46546C67, 2, len(raw)):
        raise ValueError('Expected a complete glTF 2.0 binary container')
    chunks, offset = {}, 12
    while offset < len(raw):
        length, kind = struct.unpack_from('<II', raw, offset)
        offset += 8
        if offset + length > len(raw) or kind in chunks:
            raise ValueError('Invalid or duplicate GLB chunk')
        chunks[kind] = raw[offset:offset + length]
        offset += length
    if set(chunks) - {0x4E4F534A, 0x004E4942}:
        raise ValueError('Unknown GLB chunks must not be silently discarded')
    doc = json.loads(chunks[0x4E4F534A].decode('utf-8').rstrip(' \0'))
    binary = bytearray(chunks.get(0x004E4942, b''))
    if len(doc.get('buffers', [])) != 1 or doc['buffers'][0].get('uri'):
        raise ValueError('The Pirate asset must have one embedded buffer')
    if doc['buffers'][0]['byteLength'] > len(binary):
        raise ValueError('Embedded buffer is truncated')
    binary = binary[:doc['buffers'][0]['byteLength']]
    for extension in ('KHR_draco_mesh_compression', 'EXT_meshopt_compression',
                      'EXT_mesh_gpu_instancing'):
        if extension in doc.get('extensionsUsed', []):
            raise ValueError('Pack the ordinary Blender GLB before adding ' + extension)
    return doc, binary, raw


def accessor_values(doc, binary, index):
    accessor = doc['accessors'][index]
    code, size = COMPONENT[accessor['componentType']]
    width = WIDTH[accessor['type']]
    # Blender exports float matrices, avoiding the byte-matrix padding rules.
    if accessor['type'].startswith('MAT') and size != 4:
        raise ValueError('Unsupported padded matrix accessor')
    if 'bufferView' in accessor:
        view = doc['bufferViews'][accessor['bufferView']]
        if view.get('buffer', 0) != 0:
            raise ValueError('Unexpected external buffer view')
        offset = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
        stride = view.get('byteStride', width * size)
        values = [struct.unpack_from('<' + code * width, binary, offset + row * stride)
                  for row in range(accessor['count'])]
    else:
        values = [tuple(0 for _ in range(width)) for _ in range(accessor['count'])]
    sparse = accessor.get('sparse')
    if sparse:
        indices = sparse['indices']
        index_code, index_size = COMPONENT[indices['componentType']]
        index_view = doc['bufferViews'][indices['bufferView']]
        index_offset = index_view.get('byteOffset', 0) + indices.get('byteOffset', 0)
        value_spec = sparse['values']
        value_view = doc['bufferViews'][value_spec['bufferView']]
        value_offset = value_view.get('byteOffset', 0) + value_spec.get('byteOffset', 0)
        for row in range(sparse['count']):
            at = struct.unpack_from('<' + index_code, binary, index_offset + row * index_size)[0]
            values[at] = struct.unpack_from('<' + code * width, binary, value_offset + row * width * size)
    return values


def append_float_accessor(doc, binary, values, kind, bounds=False):
    width = WIDTH[kind]
    if any(len(value) != width for value in values):
        raise ValueError('Invalid accessor sample width')
    # Bounds describe the actual float32 bytes, including shifted time values.
    values = [tuple(struct.unpack('<f', struct.pack('<f', component))[0] for component in value)
              for value in values]
    binary.extend(b'\0' * ((-len(binary)) % 4))
    offset = len(binary)
    for value in values:
        binary.extend(struct.pack('<' + 'f' * width, *value))
    view = len(doc.setdefault('bufferViews', []))
    doc['bufferViews'].append({'buffer': 0, 'byteOffset': offset,
                              'byteLength': len(values) * width * 4})
    accessor = {'bufferView': view, 'componentType': 5126,
                'count': len(values), 'type': kind}
    if bounds and values:
        accessor['min'] = [min(value[axis] for value in values) for axis in range(width)]
        accessor['max'] = [max(value[axis] for value in values) for axis in range(width)]
    index = len(doc.setdefault('accessors', []))
    doc['accessors'].append(accessor)
    return index


def sampler_frames(doc, binary, sampler):
    times = [row[0] for row in accessor_values(doc, binary, sampler['input'])]
    rows = accessor_values(doc, binary, sampler['output'])
    multiplier = 3 if sampler.get('interpolation', 'LINEAR') == 'CUBICSPLINE' else 1
    if not times or len(rows) % (len(times) * multiplier):
        raise ValueError('Animation output does not match its sample times')
    frame_width = len(rows) // len(times)
    frames = [tuple(rows[index * frame_width:(index + 1) * frame_width])
              for index in range(len(times))]
    return times, frames


def value_frame(frame, interpolation):
    if interpolation == 'CUBICSPLINE':
        size = len(frame) // 3
        return frame[size:2 * size]
    return frame


def is_constant(frames, interpolation):
    if interpolation != 'CUBICSPLINE':
        return all(frame == frames[0] for frame in frames)
    size = len(frames[0]) // 3
    values = value_frame(frames[0], interpolation)
    return all(value_frame(frame, interpolation) == values
               and all(component == 0 for row in frame[:size] + frame[2 * size:] for component in row)
               for frame in frames)


def flat_run_indices(frames, interpolation):
    if len(frames) <= 2:
        return list(range(len(frames)))
    if is_constant(frames, interpolation):
        return [0, len(frames) - 1]
    if interpolation not in ('LINEAR', 'STEP'):
        return list(range(len(frames)))
    # Both ends of each flat run remain. Removing its interior changes neither
    # the hold nor the neighbouring ramp, including a morph's opening pause.
    return [0] + [index for index in range(1, len(frames) - 1)
                  if not frames[index - 1] == frames[index] == frames[index + 1]] + [len(frames) - 1]


def pack_animation_tracks(doc, binary):
    reports = []
    for animation in doc.get('animations', []):
        samples = [sampler_frames(doc, binary, sampler) for sampler in animation['samplers']]
        start = min(times[0] for times, _frames in samples)
        end = max(times[-1] for times, _frames in samples)
        if start < -1e-6 or start > .1:
            raise ValueError('Unexpected time origin for ' + animation['name'])
        track_reports = []
        for index, (sampler, (times, frames)) in enumerate(zip(animation['samplers'], samples)):
            if any(not math.isfinite(time) for time in times) or any(b <= a for a, b in zip(times, times[1:])):
                raise ValueError('Animation time samples must increase strictly')
            if any(not math.isfinite(component) for frame in frames for row in frame for component in row):
                raise ValueError('Animation values must be finite')
            interpolation = sampler.get('interpolation', 'LINEAR')
            kept = flat_run_indices(frames, interpolation)
            shifted = [(0.0 if abs(times[at] - start) < 1e-7 else times[at] - start,) for at in kept]
            output = [row for at in kept for row in frames[at]]
            old_output = doc['accessors'][sampler['output']]
            sampler['input'] = append_float_accessor(doc, binary, shifted, 'SCALAR', True)
            sampler['output'] = append_float_accessor(doc, binary, output, old_output['type'],
                                                      'min' in old_output or 'max' in old_output)
            track_reports.append({'sampler': index, 'before_samples': len(times),
                                  'after_samples': len(kept),
                                  'constant': is_constant(frames, interpolation),
                                  'interpolation': interpolation})
        reports.append({'name': animation['name'], 'source_start_seconds': round(start, 8),
                        'source_end_seconds': round(end, 8),
                        'duration_seconds': round(end - start, 6),
                        'channels_preserved': len(animation['channels']),
                        'samples_before': sum(track['before_samples'] for track in track_reports),
                        'samples_after': sum(track['after_samples'] for track in track_reports),
                        'constant_tracks': sum(track['constant'] for track in track_reports),
                        'tracks': track_reports})
    return reports


def first_pose(doc, binary, animation):
    result = {}
    for channel in animation['channels']:
        target = channel['target']
        sampler = animation['samplers'][channel['sampler']]
        _times, frames = sampler_frames(doc, binary, sampler)
        value = value_frame(frames[0], sampler.get('interpolation', 'LINEAR'))
        result[(target['node'], target['path'])] = tuple(component for row in value for component in row)
    return result


def neutral_node_defaults(doc, binary):
    idle = next(animation for animation in doc['animations'] if animation['name'] == 'Idle')
    pose = first_pose(doc, binary, idle)
    changed = []
    for (index, path), values in pose.items():
        node = doc['nodes'][index]
        if path not in ('translation', 'rotation', 'scale', 'weights'):
            raise ValueError('Unexpected animated node property ' + path)
        if 'matrix' in node:
            raise ValueError('Animated TRS node unexpectedly retains a static matrix')
        if node.get(path) != list(values):
            node[path] = list(values)
            changed.append({'node': node.get('name', str(index)), 'property': path})
        if path == 'weights' and 'mesh' in node:
            doc['meshes'][node['mesh']]['weights'] = list(values)
    return changed


def remap_accessors(doc):
    references = []
    for mesh in doc.get('meshes', []):
        for primitive in mesh.get('primitives', []):
            references.extend((primitive['attributes'], key) for key in primitive.get('attributes', {}))
            if 'indices' in primitive:
                references.append((primitive, 'indices'))
            for target in primitive.get('targets', []):
                references.extend((target, key) for key in target)
    for skin in doc.get('skins', []):
        if 'inverseBindMatrices' in skin:
            references.append((skin, 'inverseBindMatrices'))
    for animation in doc.get('animations', []):
        for sampler in animation['samplers']:
            references.extend(((sampler, 'input'), (sampler, 'output')))
    used = sorted({container[key] for container, key in references})
    mapping = {old: new for new, old in enumerate(used)}
    for container, key in references:
        container[key] = mapping[container[key]]
    doc['accessors'] = [doc['accessors'][index] for index in used]


def buffer_view_references(value):
    if isinstance(value, dict):
        for key, item in value.items():
            if key == 'bufferView' and isinstance(item, int):
                yield value, key
            else:
                yield from buffer_view_references(item)
    elif isinstance(value, list):
        for item in value:
            yield from buffer_view_references(item)


def compact_buffer(doc, binary):
    remap_accessors(doc)
    old_views = doc['bufferViews']
    # Blender may put many unrelated accessors into a single view. Copying that
    # whole view would retain removed samples. Repack each referenced stream,
    # byte for byte, including sparse morph streams and image payloads.
    other_references = []
    for key, value in doc.items():
        if key not in ('accessors', 'bufferViews'):
            other_references.extend(buffer_view_references(value))
    vertex_accessors = set()
    for mesh in doc.get('meshes', []):
        for primitive in mesh['primitives']:
            vertex_accessors.update(primitive['attributes'].values())
            for target in primitive.get('targets', []):
                vertex_accessors.update(target.values())
    views, packed, cache = [], bytearray(), {}

    def add_view(payload, target=None, stride=None):
        token = (bytes(payload), target, stride)
        if token in cache:
            return cache[token]
        packed.extend(b'\0' * ((-len(packed)) % 4))
        view = {'buffer': 0, 'byteOffset': len(packed), 'byteLength': len(payload)}
        if target is not None:
            view['target'] = target
        if stride is not None:
            view['byteStride'] = stride
        packed.extend(payload)
        cache[token] = len(views)
        views.append(view)
        return len(views) - 1

    def stream(view_index, local_offset, count, item_size, vertex=False):
        source = old_views[view_index]
        if source.get('buffer', 0) != 0:
            raise ValueError('Unexpected external buffer during compaction')
        start = source.get('byteOffset', 0) + local_offset
        stride = source.get('byteStride', item_size)
        end = start + (count - 1) * stride + item_size if count else start
        if end > source.get('byteOffset', 0) + source['byteLength'] or end > len(binary):
            raise ValueError('Accessor exceeds its embedded buffer view')
        padded = ((item_size + 3) // 4) * 4 if vertex else item_size
        payload = bytearray()
        for row in range(count):
            at = start + row * stride
            payload.extend(binary[at:at + item_size])
            payload.extend(b'\0' * (padded - item_size))
        return add_view(payload, source.get('target'), padded if padded != item_size else None)

    for index, accessor in enumerate(doc['accessors']):
        size = COMPONENT[accessor['componentType']][1] * WIDTH[accessor['type']]
        if accessor['type'].startswith('MAT') and COMPONENT[accessor['componentType']][1] != 4:
            raise ValueError('Unsupported padded matrix accessor')
        if 'bufferView' in accessor:
            accessor['bufferView'] = stream(accessor['bufferView'], accessor.get('byteOffset', 0),
                                             accessor['count'], size, index in vertex_accessors)
            accessor.pop('byteOffset', None)
        sparse = accessor.get('sparse')
        if sparse:
            for kind, item_size in (('indices', COMPONENT[sparse['indices']['componentType']][1]),
                                    ('values', size)):
                spec = sparse[kind]
                spec['bufferView'] = stream(spec['bufferView'], spec.get('byteOffset', 0),
                                            sparse['count'], item_size)
                spec.pop('byteOffset', None)
    for container, key in other_references:
        source = old_views[container[key]]
        start, length = source.get('byteOffset', 0), source['byteLength']
        if start + length > len(binary):
            raise ValueError('Embedded resource exceeds its buffer')
        container[key] = add_view(binary[start:start + length], source.get('target'), source.get('byteStride'))
    doc['bufferViews'] = views
    doc['buffers'] = [{'byteLength': len(packed)}]
    return packed


def encode_glb(doc, binary):
    json_bytes = json.dumps(doc, separators=(',', ':'), ensure_ascii=True).encode('utf-8')
    json_bytes += b' ' * ((-len(json_bytes)) % 4)
    binary_bytes = bytes(binary) + b'\0' * ((-len(binary)) % 4)
    total = 12 + 8 + len(json_bytes) + 8 + len(binary_bytes)
    return (struct.pack('<III', 0x46546C67, 2, total)
            + struct.pack('<II', len(json_bytes), 0x4E4F534A) + json_bytes
            + struct.pack('<II', len(binary_bytes), 0x004E4942) + binary_bytes)


def same_pose(a, b, path, tolerance=2e-5):
    if len(a) != len(b):
        return False
    direct = all(abs(x - y) <= tolerance for x, y in zip(a, b))
    # A full revolution may legitimately finish with the opposite quaternion
    # sign. Never rewrite that sign in the animated samples themselves.
    return direct or (path == 'rotation' and all(abs(x + y) <= tolerance for x, y in zip(a, b)))


def rotation_travel_degrees(frames, interpolation):
    quaternions = [tuple(value for row in value_frame(frame, interpolation) for value in row)
                   for frame in frames]
    travel = 0.0
    for first, second in zip(quaternions, quaternions[1:]):
        denominator = math.sqrt(sum(value * value for value in first) * sum(value * value for value in second))
        if len(first) != 4 or denominator < 1e-12:
            raise ValueError('Invalid animated quaternion')
        dot = abs(sum(a * b for a, b in zip(first, second)) / denominator)
        travel += math.degrees(2 * math.acos(min(1, dot)))
    return travel


def channel_values(doc, binary, animation, channel):
    sampler = animation['samplers'][channel['sampler']]
    times, frames = sampler_frames(doc, binary, sampler)
    interpolation = sampler.get('interpolation', 'LINEAR')
    values = [tuple(component for row in value_frame(frame, interpolation) for component in row)
              for frame in frames]
    return times, values, interpolation


def sample_channel(times, values, interpolation, path, at):
    if interpolation == 'CUBICSPLINE':
        raise ValueError('Taunt signatures require the densely sampled LINEAR export')
    index = max(0, min(len(times) - 1, bisect_right(times, at) - 1))
    if index == len(times) - 1 or interpolation == 'STEP':
        return values[index]
    blend = (at - times[index]) / (times[index + 1] - times[index])
    first, second = values[index], values[index + 1]
    if path != 'rotation':
        return tuple(a * (1 - blend) + b * blend for a, b in zip(first, second))
    dot = sum(a * b for a, b in zip(first, second))
    if dot < 0:
        second, dot = tuple(-value for value in second), -dot
    if dot > .9995:
        result = tuple(a * (1 - blend) + b * blend for a, b in zip(first, second))
    else:
        angle = math.acos(min(1, dot))
        first_weight = math.sin((1 - blend) * angle) / math.sin(angle)
        second_weight = math.sin(blend * angle) / math.sin(angle)
        result = tuple(a * first_weight + b * second_weight for a, b in zip(first, second))
    length = math.sqrt(sum(value * value for value in result))
    return tuple(value / length for value in result)


def trajectory_signature(doc, binary, animation):
    """Compare normalized gestures independently of duration and sample count."""
    channels = []
    prepared = [(channel, *channel_values(doc, binary, animation, channel))
                for channel in animation['channels']]
    duration = max(times[-1] for _channel, times, _values, _interpolation in prepared)
    for channel, times, values, interpolation in sorted(prepared, key=lambda row:
            (row[0]['target']['node'], row[0]['target']['path'])):
        path = channel['target']['path']
        points = []
        for sample in range(33):
            value = sample_channel(times, values, interpolation, path, duration * sample / 32)
            if path == 'rotation':
                # Equivalent quaternion signs must not make copies look unique.
                sign = next((1 if component > 0 else -1 for component in reversed(value)
                             if abs(component) > 1e-8), 1)
                value = tuple(component * sign for component in value)
            points.append([0.0 if abs(component) < .000005 else round(component, 5) for component in value])
        channels.append({'node': channel['target']['node'], 'path': path, 'samples': points})
    return hashlib.sha256(json.dumps(channels, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def audit(doc, binary, encoded_size):
    errors, mesh_reports, triangles, surfaces, vertices = [], [], 0, 0, 0
    if sorted(animation['name'] for animation in doc.get('animations', [])) != sorted(CLIPS):
        errors.append('Exactly the twenty-two authored Pirate animation names are required')
    for mesh_index, mesh in enumerate(doc.get('meshes', [])):
        primitives, count, vertex_count, targets = [], 0, 0, set()
        for surface_index, primitive in enumerate(mesh.get('primitives', [])):
            surfaces += 1
            if primitive.get('mode', 4) != 4:
                errors.append('Pirate surfaces must use triangle primitives')
            attributes = primitive.get('attributes', {})
            vertex_total = doc['accessors'][attributes['POSITION']]['count']
            index_total = doc['accessors'][primitive['indices']]['count'] if 'indices' in primitive else vertex_total
            if index_total % 3:
                errors.append('A triangle surface has an incomplete triangle')
            tri_total = index_total // 3
            normal_lengths = []
            if 'NORMAL' not in attributes:
                errors.append('Every Pirate surface must retain authored normals')
            else:
                normals = accessor_values(doc, binary, attributes['NORMAL'])
                if len(normals) != vertex_total:
                    errors.append('Normal and vertex counts differ')
                for normal in normals:
                    length = math.sqrt(sum(component * component for component in normal))
                    normal_lengths.append(length)
                    if not math.isfinite(length) or abs(length - 1) > .01:
                        errors.append('Non-unit or invalid surface normal in ' + mesh.get('name', str(mesh_index)))
                        break
            for target in primitive.get('targets', []):
                for semantic, accessor in target.items():
                    values = accessor_values(doc, binary, accessor)
                    if len(values) != vertex_total or any(not math.isfinite(value) for row in values for value in row):
                        errors.append('Invalid morph ' + semantic + ' in ' + mesh.get('name', str(mesh_index)))
            target_total = len(primitive.get('targets', []))
            targets.add(target_total)
            primitives.append({'surface': surface_index, 'material': primitive.get('material'),
                               'vertices': vertex_total, 'triangles': tri_total,
                               'morph_targets': target_total,
                               'normal_length_min': round(min(normal_lengths), 6) if normal_lengths else None,
                               'normal_length_max': round(max(normal_lengths), 6) if normal_lengths else None})
            count += tri_total
            vertex_count += vertex_total
        if len(targets) > 1:
            errors.append('Morph target counts must match every surface in a mesh')
        target_names = mesh.get('extras', {}).get('targetNames', [])
        if any(targets) and (sorted(target_names) != sorted(MORPHS) or targets != {len(MORPHS)}):
            errors.append('The elastic body must retain the four named Pirate morphs')
        if target_names and (len(mesh.get('weights', [])) != len(target_names)
                             or any(abs(value) > 1e-7 for value in mesh['weights'])):
            errors.append('All default body morph weights must be explicitly zero')
        mesh_reports.append({'mesh': mesh_index, 'name': mesh.get('name'),
                             'vertices': vertex_count, 'triangles': count,
                             'target_names': mesh.get('extras', {}).get('targetNames', []),
                             'default_weights': mesh.get('weights', []), 'surfaces': primitives})
        triangles += count
        vertices += vertex_count

    idle = next((animation for animation in doc.get('animations', []) if animation['name'] == 'Idle'), None)
    reference = first_pose(doc, binary, idle) if idle else {}
    clip_reports = []
    for animation in doc.get('animations', []):
        durations, weights, rotations, reset, first_rest, moving = [], [], [], True, True, False
        channel_keys = {(channel['target']['node'], channel['target']['path']) for channel in animation['channels']}
        if not set(reference).issubset(channel_keys):
            errors.append('A clip lost a neutral/reset channel: ' + animation['name'])
        for channel in animation['channels']:
            target = channel['target']
            sampler = animation['samplers'][channel['sampler']]
            times, frames = sampler_frames(doc, binary, sampler)
            interpolation = sampler.get('interpolation', 'LINEAR')
            start_value = tuple(value for row in value_frame(frames[0], interpolation) for value in row)
            final_value = tuple(value for row in value_frame(frames[-1], interpolation) for value in row)
            rest = reference.get((target['node'], target['path']))
            if rest is not None:
                reset = reset and same_pose(final_value, rest, target['path'])
                first_rest = first_rest and same_pose(start_value, rest, target['path'])
            samples = [tuple(value for row in value_frame(frame, interpolation) for value in row)
                       for frame in frames]
            moving = moving or any(not same_pose(sample, start_value, target['path']) for sample in samples)
            if target['path'] == 'weights':
                node = doc['nodes'][target['node']]
                mesh = doc['meshes'][node['mesh']]
                names = mesh.get('extras', {}).get('targetNames', [])
                if len(start_value) != len(names) or sorted(names) != sorted(MORPHS):
                    errors.append('A weight track does not match the four morph names: ' + animation['name'])
                values = [value for sample in samples for value in sample]
                if any(abs(value) > 1e-7 for value in start_value + final_value):
                    errors.append('Every morph must reset to zero: ' + animation['name'])
                if min(values) < -1e-6 or max(values) > 1.00001:
                    errors.append('Morph weights must stay in the authored zero-to-one range')
                named_targets = []
                for index, name in enumerate(names):
                    if index >= len(start_value):
                        break
                    samples_for_target = [sample[index] for sample in samples]
                    peak_index = max(range(len(samples_for_target)), key=samples_for_target.__getitem__)
                    named_targets.append({'name': name, 'index': index,
                                          'minimum': round(min(samples_for_target), 6),
                                          'maximum': round(max(samples_for_target), 6),
                                          'start': start_value[index], 'end': final_value[index],
                                          'peak_time_seconds': round(times[peak_index], 6)})
                weights.append({'node': doc['nodes'][target['node']].get('name'),
                                'minimum': round(min(values), 6), 'maximum': round(max(values), 6),
                                'start': list(start_value), 'end': list(final_value),
                                'targets': named_targets})
            if target['path'] == 'rotation':
                rotations.append(rotation_travel_degrees(frames, interpolation))
            if abs(times[0]) > 1e-6:
                errors.append('Every animation track must start at zero: ' + animation['name'])
            durations.append(times[-1])
        if not reset or not first_rest:
            errors.append('Animation must begin and finish at neutral rest: ' + animation['name'])
        if animation['name'] in TAUNTS and not moving:
            errors.append('Every taunt must contain an actual gesture: ' + animation['name'])
        duration = max(durations)
        if animation['name'] in DURATIONS and abs(duration - DURATIONS[animation['name']]) > 1e-5:
            errors.append('The authored clip duration changed: ' + animation['name'])
        clip_reports.append({'name': animation['name'], 'duration_seconds': round(max(durations), 6),
                             'channels': len(animation['channels']), 'starts_at_rest': first_rest,
                             'ends_at_rest': reset, 'morph_tracks': weights,
                             'has_motion': moving,
                             'taunt_trajectory_sha256': trajectory_signature(doc, binary, animation)
                                 if animation['name'] in TAUNTS else None,
                             'maximum_rotation_travel_degrees': round(max(rotations, default=0), 3)})
    bite = next((clip for clip in clip_reports if clip['name'] == 'Special_BigBite'), None)
    if bite is None or not any(target['name'] == 'Bite_Open' and target['maximum'] >= .99
                               for track in bite['morph_tracks'] for target in track['targets']):
        errors.append('Special_BigBite must open its actual mouth morph fully')
    for clip in clip_reports:
        if clip['name'] != 'Special_BigBite' and any(target['name'] == 'Bite_Open' and target['maximum'] >= .99
                                                    for track in clip['morph_tracks'] for target in track['targets']):
            errors.append('The full biting mouth is reserved for Special_BigBite')
    taunt_signatures = [clip['taunt_trajectory_sha256'] for clip in clip_reports if clip['name'] in TAUNTS]
    if len(taunt_signatures) != len(TAUNTS) or len(set(taunt_signatures)) != len(TAUNTS):
        errors.append('The ten taunts must have distinct normalized motion and expression trajectories')
    spin = next((clip for clip in clip_reports if clip['name'] == 'Ultimate_CrescentSpin'), None)
    if spin is None or spin['maximum_rotation_travel_degrees'] < 700:
        errors.append('Ultimate_CrescentSpin lost its two complete turns')
    if triangles > LIMITS['triangles']:
        errors.append('Triangle budget exceeded')
    if surfaces > LIMITS['surfaces'] or len(doc.get('materials', [])) > LIMITS['materials']:
        errors.append('Surface or material budget exceeded')
    if len(doc.get('meshes', [])) != LIMITS['meshes']:
        errors.append('The game asset must have two meshes: elastic body and rigid hat')
    if encoded_size >= LIMITS['bytes_exclusive']:
        errors.append('The final GLB must be smaller than two million bytes')
    return {'budgets': LIMITS, 'bytes': encoded_size, 'triangles': triangles,
            'exported_vertices': vertices, 'mesh_count': len(mesh_reports),
            'surface_count': surfaces, 'material_count': len(doc.get('materials', [])),
            'materials': [material.get('name') for material in doc.get('materials', [])],
            'skin_count': len(doc.get('skins', [])),
            'texture_count': len(doc.get('textures', [])),
            'extensions_used': doc.get('extensionsUsed', []),
            'morph_names': list(MORPHS), 'taunt_count': len(taunt_signatures),
            'taunts_distinct': len(taunt_signatures) == len(set(taunt_signatures)) == len(TAUNTS),
            'meshes': mesh_reports, 'clips': clip_reports,
            'errors': sorted(set(errors))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    root = Path(__file__).resolve().parents[1]
    parser.add_argument('--input', default=root / 'build/pirate/pirate-game.raw.glb', type=Path)
    parser.add_argument('--output', default=root / 'assets/pirate/pirate-game.glb', type=Path)
    parser.add_argument('--audit', default=root / 'assets/pirate/optimization-report.json', type=Path)
    args = parser.parse_args()
    if args.input.resolve() == args.output.resolve():
        parser.error('Keep the Blender raw export separate from the final packed asset')
    doc, binary, source = read_glb(args.input)
    tracks = pack_animation_tracks(doc, binary)
    defaults = neutral_node_defaults(doc, binary)
    binary = compact_buffer(doc, binary)
    final = encode_glb(doc, binary)
    report = audit(doc, binary, len(final))
    report.update({'input': str(args.input), 'output': str(args.output),
                   'input_bytes': len(source), 'bytes_saved': len(source) - len(final),
                   'input_sha256': hashlib.sha256(source).hexdigest(),
                   'sha256': hashlib.sha256(final).hexdigest(),
                   'animation_postprocess': tracks, 'neutral_defaults_updated': defaults,
                   'postprocess_policy': 'Exact flat samples only; reset channels and quaternion signs retained',
                   'status': 'failed' if report['errors'] else 'passed'})
    audit_path = args.audit or args.output.with_suffix('.audit.json')
    audit_path.parent.mkdir(parents=True, exist_ok=True)
    audit_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: report[key] for key in ('status', 'input_bytes', 'bytes', 'bytes_saved',
                                                'triangles', 'surface_count', 'material_count', 'errors')}))
    if report['errors']:
        raise SystemExit(2)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(final)


if __name__ == '__main__':
    main()
