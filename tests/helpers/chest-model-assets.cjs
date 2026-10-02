const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function readModelContainer(filename) {
  const bytes = fs.readFileSync(filename);
  assert.equal(bytes.toString('ascii', 0, 4), 'glTF', filename);
  assert.equal(bytes.readUInt32LE(4), 2, filename);
  assert.equal(bytes.readUInt32LE(8), bytes.length, filename);
  assert.equal(bytes.toString('ascii', 16, 20), 'JSON', filename);
  const jsonLength = bytes.readUInt32LE(12);
  const gltf = JSON.parse(bytes.toString('utf8', 20, 20 + jsonLength));
  const binaryOffset = 20 + jsonLength;
  assert.equal(bytes.toString('ascii', binaryOffset + 4, binaryOffset + 7), 'BIN', filename);
  const binary = bytes.subarray(binaryOffset + 8, binaryOffset + 8 + bytes.readUInt32LE(binaryOffset));
  return { bytes, gltf, binary };
}

function embeddedModelImages(relativePath, model) {
  const stem = path.posix.basename(relativePath, '.glb');
  return (model.gltf.images || []).map(image => {
    assert.ok(image.name && Number.isInteger(image.bufferView), relativePath);
    assert.ok(['image/png', 'image/jpeg'].includes(image.mimeType), relativePath);
    const view = model.gltf.bufferViews[image.bufferView];
    const offset = view.byteOffset || 0;
    const extension = image.mimeType === 'image/png' ? '.png' : '.jpg';
    return {
      path: `${path.posix.dirname(relativePath)}/${stem}_${image.name}${extension}`,
      bytes: model.binary.subarray(offset, offset + view.byteLength)
    };
  });
}

function imageDimensions(bytes) {
  if (bytes.toString('ascii', 12, 16) === 'IHDR') {
    return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
  }
  assert.equal(bytes.readUInt16BE(0), 0xffd8, 'A model image is PNG or JPEG');
  let offset = 2;
  while (offset + 4 < bytes.length) {
    assert.equal(bytes[offset], 0xff, 'JPEG marker');
    while (bytes[offset] === 0xff) offset++;
    const marker = bytes[offset++];
    if ([0xd8, 0xd9].includes(marker)) continue;
    const length = bytes.readUInt16BE(offset);
    if ([0xc0, 0xc1, 0xc2].includes(marker)) {
      return { width: bytes.readUInt16BE(offset + 5), height: bytes.readUInt16BE(offset + 3) };
    }
    assert.ok(length >= 2 && offset + length <= bytes.length, 'Complete JPEG segment');
    offset += length;
  }
  assert.fail('A model JPEG needs a supported image dimension marker');
}

function readFloatAccessor(model, index) {
  const accessor = model.gltf.accessors[index];
  const components = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4 }[accessor.type];
  assert.equal(accessor.componentType, 5126, 'Animation tracks use floating-point samples');
  assert.ok(components && !accessor.sparse, 'Animation accessors have explicit samples');
  const view = model.gltf.bufferViews[accessor.bufferView];
  const offset = (view.byteOffset || 0) + (accessor.byteOffset || 0);
  const stride = view.byteStride || components * 4;
  return Array.from({ length: accessor.count }, (_, frame) =>
    Array.from({ length: components }, (_, component) => {
      const value = model.binary.readFloatLE(offset + frame * stride + component * 4);
      assert.ok(Number.isFinite(value), 'Animation samples are finite');
      return value;
    }));
}

module.exports = { readModelContainer, embeddedModelImages, imageDimensions, readFloatAccessor };
