const sharp = require(process.env.SHARP_MODULE || 'sharp');

// Adapt the acquired educational vector, retaining its paths and teaching cues.
// Source colors that carry meaning (such as a red comparison arrow) retain hue.
function softenVector(source, paletteOverrides = {}) {
  let count = 0;
  const definitions = [];
  const palette = {
    '#00ff00': '#6fbd61', '#0f0': '#6fbd61', '#ff0000': '#ed6468', '#f00': '#ed6468',
    '#ff001c': '#ed6468', '#ffff00': '#f4ce50', '#ff0': '#f4ce50',
    '#0000ff': '#5686cd', '#00f': '#5686cd', '#00ffff': '#62c7d8', '#0ff': '#62c7d8',
    '#ff00ff': '#cc76b3', '#f0f': '#cc76b3', '#c8c8c8': '#b7c7d1',
    ...paletteOverrides
  };
  const color = (kind, value) => {
    let hex = (palette[value.toLowerCase()] || value).toLowerCase();
    if (hex.length === 4) hex = '#' + [...hex.slice(1)].map(c => c + c).join('');
    const rgb = [1, 3, 5].map(p => parseInt(hex.slice(p, p + 2), 16));
    if (rgb.some(Number.isNaN)) return value;
    if (Math.max(...rgb) < 65) return '#384b59';
    if (kind === 'stroke') return hex;
    const encode = values => '#' + values.map(n => Math.round(Math.max(0, Math.min(255, n))).toString(16).padStart(2, '0')).join('');
    const light = encode(rgb.map(c => c + (255 - c) * .32));
    const mid = encode(rgb.map(c => c * .96 + 5));
    const dark = encode(rgb.map((c, i) => c * .82 + [5, 9, 13][i]));
    const id = `pip-material-${count++}`;
    definitions.push(`<radialGradient id="${id}" cx="30%" cy="20%" r="95%"><stop stop-color="${light}"/><stop offset=".42" stop-color="${mid}"/><stop offset="1" stop-color="${dark}"/></radialGradient>`);
    return `url(#${id})`;
  };
  source = source.replace(/(fill|stroke)="(#[\da-f]{3,6})"/gi, (_, kind, value) => `${kind}="${color(kind, value)}"`)
    .replace(/(fill|stroke):\s*(#[\da-f]{3,6})(?=[;}\s])/gi, (_, kind, value) => `${kind}:${color(kind, value)}`)
    .replace(/stroke-width="([\d.]+)"/g, (_, width) => `stroke-width="${Number(width) * .7}"`)
    .replace(/stroke-width:\s*([\d.]+)(px)?(?=[;}\s])/g, (_, width, unit = '') => `stroke-width:${Number(width) * .7}${unit}`);
  return source.replace(/(<svg\b[^>]*>)/, `$1<defs>${definitions.join('')}</defs><g stroke-linejoin="round" stroke-linecap="round">`)
    .replace(/<\/svg>\s*$/, '</g></svg>');
}

async function normalizePicture(bytes, vector = false, palette = {}) {
  const input = vector ? Buffer.from(softenVector(bytes.toString('utf8'), palette)) : bytes;
  const rendered = await sharp(input, { density: 144, limitInputPixels: 25000000 })
    .ensureAlpha().trim({ threshold: 8 }).resize(232, 232, { fit: 'contain', background: '#00000000' })
    .extend({ top: 12, bottom: 12, left: 12, right: 12, background: '#00000000' })
    .webp({ quality: 94, alphaQuality: 100, effort: 5 }).toBuffer();
  return rendered;
}

module.exports = { softenVector, normalizePicture };
