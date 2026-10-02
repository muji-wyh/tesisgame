"""Publish three measured giant conversions as private game build inputs."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct

from PIL import Image


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def glb_document(path):
    data = path.read_bytes()
    if struct.unpack_from('<4sII', data) != (b'glTF', 2, len(data)):
        raise ValueError('Invalid GLB: ' + str(path))
    length, kind = struct.unpack_from('<I4s', data, 12)
    if kind != b'JSON':
        raise ValueError('Missing glTF JSON')
    return json.loads(data[20:20+length])


def publish(root, converted):
    target = root / 'assets/talk_quest/monsters'
    entries = []
    for report_name in ['rock-guardian.report.json', 'giant-storm-dragon.json', 'giant-ember-golem.json']:
        entry = json.loads((converted / report_name).read_text(encoding='utf8'))
        source = converted / entry['file']
        if sha256(source) != entry['sha256']:
            raise ValueError('Conversion bytes differ from report: ' + entry['id'])
        document = glb_document(source)
        animations = {item['name']: item for item in document.get('animations', [])}
        if not {'Idle','Attack','Hit'}.issubset(animations) or not document.get('skins'):
            raise ValueError('A giant must have a skin and three measured skeletal clips')
        for mesh in document['meshes']:
            for primitive in mesh['primitives']:
                if not {'JOINTS_0','WEIGHTS_0','TEXCOORD_0'}.issubset(primitive['attributes']):
                    raise ValueError('Missing skin weights or original texture UVs')
        for material in document['materials']:
            if 'baseColorTexture' not in material.get('pbrMetallicRoughness', {}):
                raise ValueError('Original albedo texture is missing')
        if not document.get('images') or any('bufferView' not in image for image in document['images']):
            raise ValueError('Source textures must be embedded in the private GLB')
        for role, animation in entry['animations'].items():
            if animation.get('valid') is False:
                raise ValueError('Rejected deformation sample: ' + role)
        filename = entry['id'] + '.glb'
        shutil.copyfile(source, target / filename)
        entry['file'] = filename
        entry['resource'] = 'res://assets/talk_quest/monsters/' + filename
        entry.pop('output_path', None)
        preview = converted / (entry['id'] + '.png')
        if not preview.exists():
            preview = source.with_suffix('.png')
        if preview.exists():
            image = Image.open(preview).convert('RGBA')
            bounds = image.getchannel('A').getbbox()
            if bounds:
                image = image.crop(bounds)
                image.thumbnail((288,288), Image.Resampling.LANCZOS)
                padded = Image.new('RGBA',(image.width+32,image.height+32))
                padded.paste(image,(16,16))
                thumbnail = target / (entry['id'] + '.png')
                padded.save(thumbnail)
                entry.update(thumbnail='res://assets/talk_quest/monsters/'+thumbnail.name,
                             thumbnail_sha256=sha256(thumbnail))
        entries.append(entry)
    manifest = {'version':1, 'coordinates':'Godot Y-up, front +Z, standing floor y=0',
                'source_manifest':'docs/assets/talk-quest-giants-sources.json',
                'source_manifest_sha256':sha256(root/'docs/assets/talk-quest-giants-sources.json'),
                'total_glb_bytes':sum(entry['bytes'] for entry in entries), 'creatures':entries}
    (target/'giants-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
    print(f"Published {len(entries)} giant creatures, {manifest['total_glb_bytes']} GLB bytes.")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--converted',type=Path,default=Path('build/talk-quest-giants'))
    args = parser.parse_args()
    publish(Path(__file__).resolve().parents[2],args.converted)
