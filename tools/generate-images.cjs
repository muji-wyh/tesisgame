const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const outline = '#765445';

function smile(x, y, spacing = 10) {
  return `
    <circle cx="${x - spacing}" cy="${y}" r="3" fill="${outline}" stroke="none"/>
    <circle cx="${x + spacing}" cy="${y}" r="3" fill="${outline}" stroke="none"/>
    <path d="M${x - 6} ${y + 10} Q${x} ${y + 16} ${x + 6} ${y + 10}" fill="none"/>`;
}

function rays(y, count, inner, outer, color, width) {
  return Array.from({ length: count }, (_, index) =>
    `<line x1="60" y1="${y - inner}" x2="60" y2="${y - outer}" transform="rotate(${index * 360 / count} 60 ${y})" stroke="${color}" stroke-width="${width}"/>`
  ).join('\n    ');
}

// Original vector art only; no downloaded art, fonts, or embedded images.
const wordArt = {
  ...require(path.join(__dirname, 'word-art', 'animals.cjs')),
  ...require(path.join(__dirname, 'word-art', 'nature.cjs')),
  ...require(path.join(__dirname, 'word-art', 'food-body.cjs')),
  ...require(path.join(__dirname, 'word-art', 'everyday.cjs')),
  ...require(path.join(__dirname, 'word-art', 'ocean-space.cjs')),
  ...require(path.join(__dirname, 'word-art', 'garden-music-clothes.cjs')),
  cat: `
    <ellipse cx="60" cy="103" rx="34" ry="5" fill="#eadbc5" stroke="none"/>
    <path d="M29 53 24 23 Q23 18 28 20 L44 33 Q60 28 76 33 L92 20 Q97 18 96 23 L91 53 Q100 84 79 95 Q60 104 41 95 Q20 84 29 53Z" fill="#efb36b"/>
    <path d="M31 29 35 47 44 39Z M89 29 85 47 76 39Z" fill="#f4c2b3" stroke="none"/>
    <path d="M52 34 54 44 M60 33 60 45 M68 34 66 44" stroke="#cd854a"/>
    <ellipse cx="45" cy="78" rx="10" ry="7" fill="#f7d7b0" stroke="none"/>
    <ellipse cx="75" cy="78" rx="10" ry="7" fill="#f7d7b0" stroke="none"/>
    <circle cx="46" cy="63" r="3.5" fill="${outline}" stroke="none"/>
    <circle cx="74" cy="63" r="3.5" fill="${outline}" stroke="none"/>
    <path d="M55 73 Q60 70 65 73 L60 78Z" fill="#db8e8c" stroke-width="2.5"/>
    <path d="M60 78V81 Q54 87 50 81 M60 81 Q66 87 70 81" stroke-width="2.5"/>
    <path d="M36 74 18 70 M36 81 17 83 M84 74 102 70 M84 81 103 83" stroke-width="2.5"/>`,
  dog: `
    <ellipse cx="60" cy="104" rx="35" ry="5" fill="#eadbc5" stroke="none"/>
    <ellipse cx="29" cy="59" rx="15" ry="28" transform="rotate(16 29 59)" fill="#bf875e"/>
    <ellipse cx="91" cy="59" rx="15" ry="28" transform="rotate(-16 91 59)" fill="#bf875e"/>
    <path d="M30 51 Q30 28 60 28 Q90 28 90 51 L90 74 Q88 100 60 101 Q32 100 30 74Z" fill="#e9bc83"/>
    <path d="M37 42 Q46 33 53 41 Q58 56 49 65 Q34 62 37 42Z" fill="#d49b67" stroke="none"/>
    <circle cx="45" cy="61" r="3.5" fill="${outline}" stroke="none"/>
    <circle cx="75" cy="61" r="3.5" fill="${outline}" stroke="none"/>
    <ellipse cx="60" cy="80" rx="23" ry="15" fill="#fff0d2" stroke="none"/>
    <path d="M51 72 Q60 68 69 72 Q68 81 60 82 Q52 81 51 72Z" fill="${outline}" stroke="none"/>
    <path d="M60 81V85 Q55 90 50 86 M60 85 Q65 90 70 86" stroke-width="2.5"/>
    <path d="M56 90 Q60 92 64 90 V94 Q60 100 56 94Z" fill="#e8a5a0" stroke-width="2"/>`,
  sun: `
    ${rays(60, 12, 39, 49, '#e9ad45', 5.5)}
    <circle cx="60" cy="60" r="29" fill="#f8d86d"/>
    <path d="M42 49 Q47 40 55 39" stroke="#fff0b1" stroke-width="5"/>
    <ellipse cx="43" cy="68" rx="5" ry="3" fill="#efb78a" stroke="none"/>
    <ellipse cx="77" cy="68" rx="5" ry="3" fill="#efb78a" stroke="none"/>
    ${smile(60, 58)}`,
  ball: `
    <ellipse cx="60" cy="105" rx="34" ry="5" fill="#eadbc5" stroke="none"/>
    <circle cx="60" cy="61" r="39" fill="#f7d473"/>
    <path d="M60 22 A39 39 0 0 1 94 80 Q84 59 60 61 Q71 39 60 22Z" fill="#ed9987"/>
    <path d="M94 80 A39 39 0 0 1 26 80 Q48 75 60 61 Q75 81 94 80Z" fill="#8bcabb"/>
    <path d="M26 80 A39 39 0 0 1 60 22 Q45 40 60 61 Q40 52 26 80Z" fill="#9ec9e0"/>
    <circle cx="60" cy="61" r="7" fill="#fff3d8" stroke-width="2.5"/>
    <path d="M33 49 Q35 41 42 37" stroke="#e6f5f7" stroke-width="5"/>`,
  car: `
    <ellipse cx="60" cy="103" rx="45" ry="5" fill="#eadbc5" stroke="none"/>
    <path d="M16 72 Q16 64 27 63 L37 42 Q41 35 49 35 H70 Q78 35 84 44 L95 63 Q105 65 105 74 V83 Q105 88 98 88 H23 Q15 88 15 81Z" fill="#ef9a84"/>
    <path d="M43 45 Q45 42 49 42 H58 V61 H35Z" fill="#d3edf0" stroke-width="2.5"/>
    <path d="M65 42 H70 Q75 42 78 47 L86 61 H65Z" fill="#d3edf0" stroke-width="2.5"/>
    <path d="M61 67V81 M68 70H74" stroke-width="2.5"/>
    <rect x="95" y="68" width="8" height="8" rx="3" fill="#ffe49a" stroke-width="2"/>
    <rect x="16" y="70" width="6" height="8" rx="2" fill="#f5cf9a" stroke-width="2"/>
    <circle cx="35" cy="87" r="12" fill="#6d6866"/>
    <circle cx="86" cy="87" r="12" fill="#6d6866"/>
    <circle cx="35" cy="87" r="5" fill="#f8ead3" stroke="none"/>
    <circle cx="86" cy="87" r="5" fill="#f8ead3" stroke="none"/>`,
  apple: `
    <ellipse cx="60" cy="105" rx="31" ry="5" fill="#eadbc5" stroke="none"/>
    <path d="M60 39 Q61 27 56 20" stroke-width="5"/>
    <path d="M62 30 Q67 13 88 17 Q84 33 62 30Z" fill="#91bd7e"/>
    <path d="M60 38 C43 26 24 38 26 58 C24 76 37 100 49 98 Q60 94 71 98 C84 100 97 76 95 58 C96 37 76 27 60 38Z" fill="#e97d72"/>
    <path d="M40 45 Q33 51 34 62" stroke="#ffd0b7" stroke-width="6"/>
    <ellipse cx="43" cy="75" rx="5" ry="3" fill="#f6ab95" stroke="none"/>
    <ellipse cx="77" cy="75" rx="5" ry="3" fill="#f6ab95" stroke="none"/>
    ${smile(60, 64, 11)}`,
  fish: `
    <path d="M45 38 Q55 23 69 41 M46 83 Q58 100 70 80" fill="#f0bc72"/>
    <path d="M79 57 103 41 Q106 61 103 83 L79 68Z" fill="#efad72"/>
    <path d="M91 57 101 51 M91 68 101 75" stroke="#cb8c5d" stroke-width="2.5"/>
    <ellipse cx="53" cy="61" rx="34" ry="26" fill="#f5c47f"/>
    <path d="M59 53 Q78 57 63 72 Q58 65 59 53Z" fill="#ec9b79" stroke-width="2.5"/>
    <path d="M48 44 Q54 59 48 77" stroke="#cf975d" stroke-width="2.5"/>
    <circle cx="35" cy="54" r="4" fill="${outline}" stroke="none"/>
    <circle cx="36" cy="53" r="1.3" fill="#fff8eb" stroke="none"/>
    <path d="M21 65 Q28 71 33 65" stroke-width="2.5"/>
    <circle cx="34" cy="67" r="4" fill="#efad8a" stroke="none"/>
    <circle cx="92" cy="27" r="5" stroke="#9bc9d5" stroke-width="2.5"/>
    <circle cx="103" cy="16" r="3" fill="#c7e6e6" stroke="none"/>`,
  duck: `
    <ellipse cx="60" cy="101" rx="39" ry="6" fill="#d7e9e5" stroke="none"/>
    <path d="M32 62 Q21 68 18 55 Q10 81 34 94 Q58 105 82 90 Q100 74 78 59 L61 57Z" fill="#f8d46f"/>
    <path d="M58 68 Q62 61 59 50 Q54 28 73 24 Q93 20 95 40 Q97 56 81 63 L79 72" fill="#f8d46f"/>
    <path d="M93 41 Q104 39 108 47 Q104 55 93 53Z" fill="#eaaa62" stroke-width="2.5"/>
    <circle cx="82" cy="39" r="3.5" fill="${outline}" stroke="none"/>
    <circle cx="80" cy="50" r="4" fill="#efb58a" stroke="none"/>
    <path d="M34 75 Q49 63 68 74 Q65 91 48 88 Q38 86 34 75Z" fill="#f4c15e" stroke-width="2.5"/>
    <path d="M34 103H45 M77 103H88" stroke="#9ec8c8" stroke-width="2.5"/>`
};

const rewardArt = {
  spring: {
    title: 'Spring flower',
    background: '#edf8ec',
    shapes: `
    <path d="M60 68V103" stroke="#438363" stroke-width="6"/>
    <path d="M59 92 Q38 93 36 77 Q54 76 59 92Z M62 86 Q64 71 83 72 Q82 86 62 86Z" fill="#b9df9f" stroke="#438363" stroke-width="2.5"/>
    ${Array.from({ length: 6 }, (_, index) => `<ellipse cx="60" cy="28" rx="12" ry="16" transform="rotate(${index * 60} 60 49)" fill="#8ecf6b" stroke="#438363" stroke-width="2.5"/>`).join('\n    ')}
    <circle cx="60" cy="49" r="18" fill="#f2d66a" stroke="#438363" stroke-width="2.5"/>
    <circle cx="53" cy="45" r="3" fill="#438363" stroke="none"/>
    <circle cx="67" cy="45" r="3" fill="#438363" stroke="none"/>
    <path d="M54 55 Q60 61 66 55" stroke="#438363" stroke-width="3" fill="none"/>`
  },
  summer: {
    title: 'Summer sun',
    background: '#ffe6e6',
    shapes: `
    ${rays(56, 10, 34, 48, '#b53640', 6)}
    <circle cx="60" cy="56" r="26" fill="#ff8f9d" stroke="#b53640" stroke-width="3"/>
    <path d="M44 47 Q49 39 57 39" stroke="#ffd2d7" stroke-width="5"/>
    <circle cx="51" cy="53" r="3" fill="#b53640" stroke="none"/>
    <circle cx="69" cy="53" r="3" fill="#b53640" stroke="none"/>
    <path d="M54 63 Q60 69 66 63" stroke="#b53640" stroke-width="3" fill="none"/>
    <circle cx="30" cy="95" r="4" fill="#ffb6bf" stroke="none"/>
    <circle cx="90" cy="95" r="4" fill="#ffb6bf" stroke="none"/>
    <path d="M46 102 Q60 109 74 102" stroke="#ff8f9d" stroke-width="4"/>`
  },
  autumn: {
    title: 'Autumn maple leaf',
    background: '#fff8cf',
    shapes: `
    <path d="M60 86 57 106" stroke="#8f7400" stroke-width="5"/>
    <path d="M60 15 71 39 86 31 81 53 101 49 92 66 104 72 75 83 63 94 57 94 45 83 16 72 28 66 19 49 39 53 34 31 49 39Z" fill="#ffd24d" stroke="#8f7400"/>
    <path d="M60 91V32 M60 69 43 51 M60 69 77 51 M60 82 34 71 M60 82 86 71" stroke="#b79600" stroke-width="3"/>
    <path d="M57 34V49" stroke="#fff1a8" stroke-width="3"/>`
  },
  winter: {
    title: 'Winter snowflake',
    background: '#ffffff',
    shapes: `
    <circle cx="60" cy="60" r="43" fill="#d8dee3" stroke="#606a73" stroke-width="4"/>
    <g stroke="#606a73" stroke-width="6">
      ${Array.from({ length: 6 }, (_, index) => `<path d="M60 60V18 M60 31 50 23 M60 31 70 23 M60 46 50 38 M60 46 70 38" transform="rotate(${index * 60} 60 60)"/>`).join('\n      ')}
    </g>
    <g stroke="#ffffff" stroke-width="3">
      ${Array.from({ length: 6 }, (_, index) => `<path d="M60 60V18 M60 31 50 23 M60 31 70 23 M60 46 50 38 M60 46 70 38" transform="rotate(${index * 60} 60 60)"/>`).join('\n      ')}
    </g>
    <circle cx="60" cy="60" r="12" fill="#ffffff" stroke="#606a73" stroke-width="3"/>
    <circle cx="55" cy="56" r="2.5" fill="#606a73" stroke="none"/>
    <circle cx="65" cy="56" r="2.5" fill="#606a73" stroke="none"/>
    <path d="M54 64 Q60 69 66 64" stroke="#606a73" stroke-width="2.5" fill="none"/>`
  },
  ocean: {
    title: 'Ocean wave',
    background: '#e4f6fb',
    shapes: `
    <path d="M17 83 Q35 78 42 54 Q52 19 78 28 Q98 34 95 55 Q86 41 73 48 Q58 58 73 72 Q86 84 104 75 L99 98H22Z" fill="#69cbd6" stroke="#216d89"/>
    <path d="M45 50 Q55 28 77 31 Q94 35 92 47 Q79 37 68 47 Q57 58 66 70" stroke="#eefbfd" stroke-width="6"/>
    <path d="M27 86 Q45 79 56 83 Q73 95 93 84" stroke="#216d89" stroke-width="3"/>
    <circle cx="24" cy="36" r="5" fill="#b8e6ed" stroke="#216d89" stroke-width="2"/>
    <circle cx="34" cy="21" r="3" fill="#b8e6ed" stroke="none"/>`
  },
  space: {
    title: 'Space rocket',
    background: '#eeeafa',
    shapes: `<circle cx="60" cy="60" r="45" fill="#d7ccef" stroke="#69569b" stroke-width="3"/>
    <g transform="translate(12 9) scale(.8)">${wordArt.rocket}</g>
    <path d="M21 32V42 M16 37H26 M99 71V81 M94 76H104" stroke="#69569b" stroke-width="3"/>`
  }
};

const collectibleColors = {
  spring: ['#438363', '#8ecf6b', '#f2d66a'],
  summer: ['#b53640', '#ff8f9d', '#ffd36a'],
  autumn: ['#8f7400', '#ffd24d', '#d98a4e'],
  winter: ['#606a73', '#d8dee3', '#9bc9d5'],
  ocean: ['#216d89', '#69cbd6', '#f0cf93'],
  space: ['#69569b', '#bba3eb', '#f2d492']
};

function starPoints(points, outer, inner, rotation = -90) {
  return Array.from({ length: points * 2 }, (_, index) => {
    const angle = (rotation + index * 180 / points) * Math.PI / 180;
    const radius = index % 2 ? inner : outer;
    return `${60 + Math.cos(angle) * radius},${60 + Math.sin(angle) * radius}`;
  }).join(' ');
}

function collectibleShapes(season, index) {
  const [dark, bright, highlight] = collectibleColors[season];
  const newMedals = {
    ocean: ['whale', 'shell', 'crab', 'coral', 'squid', 'clam'],
    space: ['rocket', 'planet', 'comet', 'rover', 'galaxy', 'earth']
  };
  if (newMedals[season]) {
    return `<circle cx="60" cy="60" r="49" fill="${bright}" stroke="${dark}" stroke-width="3"/>
    <circle cx="60" cy="60" r="43" fill="${rewardArt[season].background}" stroke="${highlight}" stroke-width="3"/>
    <g transform="translate(17 17) scale(.72)">${wordArt[newMedals[season][index - 1]]}</g>
    <path d="M42 101 48 116 60 110 72 116 78 101" fill="${highlight}" stroke="${dark}" stroke-width="2.5"/>`;
  }
  const marker = Array.from({ length: { spring: 5, summer: 8, autumn: 6, winter: 4 }[season] }, (_, item) =>
    `<circle cx="60" cy="16" r="${2 + index % 3}" transform="rotate(${item * 360 / ({ spring: 5, summer: 8, autumn: 6, winter: 4 }[season])} 60 60)" fill="${highlight}" stroke="none"/>`
  ).join('\n    ');
  const motifs = [
    `${Array.from({ length: 6 }, (_, item) => `<ellipse cx="60" cy="37" rx="11" ry="18" transform="rotate(${item * 60} 60 60)" fill="${bright}"/>`).join('\n    ')}
    <circle cx="60" cy="60" r="16" fill="${highlight}"/>`,
    `<path d="M60 94 C38 78 24 65 28 47 C31 32 50 30 60 44 C70 30 89 32 92 47 C96 65 82 78 60 94Z" fill="${bright}"/>
    <path d="M44 48 Q50 39 57 44" stroke="${highlight}" stroke-width="5"/>`,
    `<polygon points="${starPoints(7, 40, 19, -90 + index * 3)}" fill="${bright}"/>
    <circle cx="60" cy="60" r="10" fill="${highlight}"/>`,
    `<polygon points="60,19 94,55 60,101 26,55" fill="${bright}"/>
    <path d="M60 19 60 101 M26 55H94 M60 19 26 55 60 70 94 55Z" stroke="${highlight}" stroke-width="4"/>`,
    `<path d="M78 25 A39 39 0 1 0 94 82 A31 31 0 1 1 78 25Z" fill="${bright}"/>
    <circle cx="79" cy="45" r="5" fill="${highlight}"/>`,
    `<path d="M25 86 31 39 49 55 60 27 71 55 89 39 95 86Z" fill="${bright}"/>
    <path d="M31 72H89" stroke="${highlight}" stroke-width="6"/>`,
    `<ellipse cx="42" cy="49" rx="18" ry="27" transform="rotate(-28 42 49)" fill="${bright}"/>
    <ellipse cx="78" cy="49" rx="18" ry="27" transform="rotate(28 78 49)" fill="${bright}"/>
    <ellipse cx="46" cy="78" rx="14" ry="20" transform="rotate(28 46 78)" fill="${highlight}"/>
    <ellipse cx="74" cy="78" rx="14" ry="20" transform="rotate(-28 74 78)" fill="${highlight}"/>
    <path d="M60 43V91 M58 43 49 31 M62 43 71 31" stroke="${dark}" stroke-width="4"/>`,
    `<path d="M60 101V57" stroke="${dark}" stroke-width="7"/>
    <path d="M58 73 Q31 70 29 45 Q54 43 60 65Z M62 62 Q66 35 93 34 Q92 59 62 68Z" fill="${bright}"/>
    <circle cx="60" cy="94" r="8" fill="${highlight}"/>`,
    `<ellipse cx="60" cy="60" rx="42" ry="19" transform="rotate(${index * 11} 60 60)" stroke="${bright}" stroke-width="7"/>
    <ellipse cx="60" cy="60" rx="19" ry="42" transform="rotate(${index * -7} 60 60)" stroke="${highlight}" stroke-width="5"/>
    <circle cx="60" cy="60" r="16" fill="${bright}"/>`,
    `<path d="M60 18 94 32 88 76 Q82 94 60 104 Q38 94 32 76 L26 32Z" fill="${bright}"/>
    <polygon points="${starPoints(5 + index % 3, 23, 11, -90)}" fill="${highlight}"/>`
  ];
  return `${marker}
    <circle cx="60" cy="60" r="${48 - index % 4}" fill="none" stroke="${dark}" stroke-width="3"/>
    <g fill="none" stroke="${dark}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
      ${motifs[index - 1]}
    </g>`;
}

const bearArt = `
    <ellipse cx="60" cy="108" rx="35" ry="5" fill="#eadbc5" stroke="none"/>
    <path d="M34 106 Q30 89 44 84 H76 Q90 89 86 106Z" fill="#9ac9bb"/>
    <ellipse cx="25" cy="83" rx="11" ry="14" transform="rotate(20 25 83)" fill="#c9956e"/>
    <ellipse cx="94" cy="77" rx="11" ry="15" transform="rotate(-22 94 77)" fill="#c9956e"/>
    <ellipse cx="94" cy="79" rx="5" ry="6" fill="#e7bc97" stroke="none"/>
    <circle cx="33" cy="35" r="14" fill="#c9956e"/>
    <circle cx="87" cy="35" r="14" fill="#c9956e"/>
    <circle cx="33" cy="35" r="7" fill="#edc8a4" stroke="none"/>
    <circle cx="87" cy="35" r="7" fill="#edc8a4" stroke="none"/>
    <ellipse cx="60" cy="62" rx="33" ry="32" fill="#d5a57d"/>
    <ellipse cx="60" cy="75" rx="19" ry="14" fill="#fae7ca" stroke="none"/>
    <circle cx="46" cy="57" r="3.5" fill="${outline}" stroke="none"/>
    <circle cx="74" cy="57" r="3.5" fill="${outline}" stroke="none"/>
    <ellipse cx="39" cy="68" rx="5" ry="3" fill="#e9b19c" stroke="none"/>
    <ellipse cx="81" cy="68" rx="5" ry="3" fill="#e9b19c" stroke="none"/>
    <path d="M54 69 Q60 66 66 69 Q66 75 60 76 Q54 75 54 69Z" fill="${outline}" stroke="none"/>
    <path d="M60 76V79 M51 79 Q60 90 69 79" stroke-width="2.5"/>
    <path d="M101 54 104 49 M107 62 112 60" stroke="#bd9b71" stroke-width="3"/>`;

function makeSvg(title, shapes, background = '#fff8eb') {
  const safeTitle = title.replace(/[&<>"']/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;'
  })[character]);
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120" role="img" aria-labelledby="title">
  <title id="title">${safeTitle}</title>
  <circle cx="60" cy="60" r="55" fill="${background}"/>
  <g fill="none" stroke="${outline}" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">${shapes}
  </g>
</svg>
`;
}

function generateImages() {
  const words = JSON.parse(fs.readFileSync(path.join(root, 'words.json'), 'utf8'));
  if (!Array.isArray(words) || words.length !== Object.keys(wordArt).length) {
    throw new Error('words.json must describe every supported word illustration exactly once.');
  }
  const seen = new Set();
  const outputs = [];
  for (const word of words) {
    if (!word || !Object.hasOwn(wordArt, word.id) || seen.has(word.id) ||
        word.image !== `assets/images/words/${word.id}.svg` ||
        typeof word.text !== 'string' || !word.text.trim()) {
      throw new Error('Invalid or unsupported illustration entry in words.json.');
    }
    seen.add(word.id);
    outputs.push([word.image, makeSvg(word.text, wordArt[word.id])]);
  }
  for (const [season, art] of Object.entries(rewardArt)) {
    outputs.push([`assets/images/rewards/${season}.svg`, makeSvg(art.title, art.shapes, art.background)]);
    const medalCount = ['ocean', 'space'].includes(season) ? 6 : 10;
    for (let index = 1; index <= medalCount; index++) {
      outputs.push([
        `assets/images/rewards/${season}-${index}.svg`,
        makeSvg(`${art.title} collectible ${index}`, collectibleShapes(season, index), art.background)
      ]);
    }
  }
  outputs.push(['assets/images/scenes/try-again.svg', makeSvg('A friendly bear waving encouragement', bearArt)]);

  for (const [relativePath, svg] of outputs) {
    const filename = path.join(root, relativePath);
    fs.mkdirSync(path.dirname(filename), { recursive: true });
    fs.writeFileSync(filename, svg, 'utf8');
  }
  console.log(`Generated ${outputs.length} original SVG images.`);
}

if (require.main === module) generateImages();

module.exports = { generateImages };
