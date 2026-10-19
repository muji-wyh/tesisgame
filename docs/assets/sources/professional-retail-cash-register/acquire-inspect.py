"""Retain and inspect the author-provided free archive exactly once; no rendering."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import zipfile
from datetime import datetime, timezone

BASE = Path(__file__).resolve().parent
ARCHIVE = Path('C:/Users/yaohuiwang/Downloads/Tiny_Treats_Bakery_Interior_1.1_FREE.zip')
EXPECTED = '1754373c399dd9b7eb074cc12367ea8f31ffc2cf7d1a9f8027b9661a0aafb562'
PREFIX = 'Tiny_Treats_Bakery_Interior_1.1_FREE/'
sha = lambda data: hashlib.sha256(data).hexdigest()

def save(relative, data):
    target = (BASE / relative).resolve()
    assert target.is_relative_to(BASE), relative
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open('xb') as file:
        file.write(data)

data = ARCHIVE.read_bytes()
assert sha(data) == EXPECTED
save('source/Tiny_Treats_Bakery_Interior_1.1_FREE.zip', data)
with zipfile.ZipFile(ARCHIVE) as archive:
    inventory = []
    for item in archive.infolist():
        assert item.filename.startswith(PREFIX)
        assert '..' not in PurePosixPath(item.filename).parts
        if item.is_dir():
            continue
        content = archive.read(item)
        inventory.append({'path': item.filename, 'bytes': len(content), 'sha256': sha(content), 'compressed_bytes': item.compress_size})
    chosen = ['License.txt', 'overview.png', 'overview_1.1.png', 'sample.png', 'Assets/gltf/cash_register.gltf', 'Assets/gltf/cash_register.bin', 'Assets/gltf/tiny_treats_texture_1.png']
    selected = []
    for relative in chosen:
        content = archive.read(PREFIX + relative)
        out = 'source/original/' + relative
        save(out, content)
        selected.append({'archive_path': PREFIX + relative, 'path': out, 'bytes': len(content), 'sha256': sha(content)})
    document = json.loads(archive.read(PREFIX + 'Assets/gltf/cash_register.gltf'))
    buffer = archive.read(PREFIX + 'Assets/gltf/cash_register.bin')
    assert len(buffer) == document['buffers'][0]['byteLength']
    for family in ['buffers', 'images']:
        for reference in document.get(family, []):
            uri = reference.get('uri')
            assert uri and not uri.startswith(('data:', '/', 'http')) and '..' not in PurePosixPath(uri).parts
            assert PREFIX + 'Assets/gltf/' + uri in archive.namelist()
    meshes = []
    for mesh in document['meshes']:
        primitives = []
        for primitive in mesh['primitives']:
            position = document['accessors'][primitive['attributes']['POSITION']]
            indices = document['accessors'][primitive['indices']]
            assert primitive.get('mode', 4) == 4 and indices['count'] % 3 == 0
            primitives.append({'vertices': position['count'], 'triangles': indices['count'] // 3, 'min': position['min'], 'max': position['max'], 'material_index': primitive['material'], 'attributes': primitive['attributes']})
        meshes.append({'name': mesh['name'], 'primitives': primitives})
    record = {
        'recorded_at': datetime.now(timezone.utc).isoformat(),
        'status': 'acquired_for_scratch_source_inspection_only',
        'sense_id': 'cash-register.sales-device.n',
        'source': 'https://tinytreats.itch.io/bakery-interior',
        'creator': 'Isa Lousberg',
        'publisher': 'Tiny Treats',
        'version': 'Bakery Interior 1.1 FREE; archive license dated 2025-10-28',
        'license': 'CC0 1.0',
        'license_url': 'http://creativecommons.org/publicdomain/zero/1.0/',
        'license_basis': 'Official source page and original archive License.txt explicitly permit personal, educational and commercial projects; credit is optional.',
        'acquisition': {'method': 'Official itch.io page: Download Now, No thanks just take me to the downloads, Free v1.1 Download', 'login': False, 'payment': False, 'archive_original_download': str(ARCHIVE).replace('\\', '/'), 'archive_path': 'source/Tiny_Treats_Bakery_Interior_1.1_FREE.zip', 'archive_bytes': len(data), 'archive_sha256': EXPECTED},
        'source_preview': {'url': 'https://img.itch.zone/aW1hZ2UvMzYyOTI0MC8yMTYwMTA0Ni5wbmc=/original/dZZBdw.png', 'inspection': 'Full-size official lineup preview inspected through the Edge source-page lightbox. Bottom-right standalone lavender register visibly has a raised physical keypad, dark display face, integrated drawer base with handle, and secondary receipt. Model suitability at actual WordCard scale remains untested.', 'reused_as_production_art': False},
        'files': selected,
        'model_structure': {'generator': document['asset']['generator'], 'scene': document['scene'], 'scenes': document['scenes'], 'nodes': document['nodes'], 'meshes': meshes, 'materials': document['materials'], 'images': document['images'], 'buffers': document['buffers'], 'textures': document['textures'], 'samplers': document['samplers'], 'extensions_used': document.get('extensionsUsed', [])},
        'available_animations': document.get('animations', []),
        'skins': document.get('skins', []),
        'animation_evidence': 'Original cash_register.gltf has no animations or skins arrays. The handle is an original child mesh; its transform is preserved. No animation has been invented or claimed.',
        'totals': {'meshes': len(meshes), 'nodes': len(document['nodes']), 'triangles': sum(p['triangles'] for m in meshes for p in m['primitives']), 'vertices': sum(p['vertices'] for m in meshes for p in m['primitives']), 'archive_files': len(inventory)},
        'scope': ['Only original source bytes retained; no geometry, material, texture or transform edits.', 'Source previews and acquired model are separate evidence states.', 'Native source inspection, term candidate, actual WordCard visual review, root acceptance, and production integration remain pending.', 'No production files, shared tests, readiness gates, or media decisions changed.'],
    }
    save('archive-inventory.json', (json.dumps(inventory, indent=2) + '\n').encode())
    save('source-record.json', (json.dumps(record, indent=2) + '\n').encode())
    print(json.dumps({'source_record_sha256': sha((BASE / 'source-record.json').read_bytes()), 'selected': selected, 'totals': record['totals']}, indent=2))
