const fs = require('node:fs');
const path = require('node:path');
const animals = require('../word-art/animals.cjs');
const food = require('../word-art/food-body.cjs');
const growing = require('../word-art/age-expansion.cjs');

const jungleLeaves = `
  <path d="M23 85 Q6 57 17 27 Q43 43 36 71Z" fill="#9ac56b" stroke="#39744b"/>
  <path d="M94 85 Q113 57 101 27 Q77 43 84 71Z" fill="#75b677" stroke="#39744b"/>
  <path d="M24 76 20 42 M26 60 15 51 M28 67 36 55 M94 76 99 42 M95 60 105 51 M93 67 85 55" stroke="#548b4f" stroke-width="2.5"/>`;

const explorerHat = `
${jungleLeaves}
  <path d="M32 64 Q30 30 56 27 Q82 24 88 64Z" fill="#e7c180" stroke="#795b36"/>
  <path d="M37 55 Q60 64 84 55 L88 68 Q60 78 31 67Z" fill="#b18c53" stroke="#795b36" stroke-width="2.5"/>
  <path d="M21 67 Q58 80 96 67 Q109 73 94 83 Q63 97 28 84 Q10 77 21 67Z" fill="#f3d79e" stroke="#795b36"/>
  <path d="M46 37 Q59 31 69 35" stroke="#fff0c5" stroke-width="5"/>
  <rect x="59" y="59" width="12" height="11" rx="2" fill="#efc461" stroke="#795b36" stroke-width="2.5"/>
  <path d="M64 61V68" stroke="#795b36" stroke-width="2"/>`;

const lollipop = `
  <path d="M62 70 78 106" stroke="#91705e" stroke-width="8"/>
  <path d="M62 70 78 106" stroke="#fff4e9" stroke-width="4"/>
  <circle cx="54" cy="46" r="34" fill="#f3a7c9"/>
  <path d="M54 45 C63 32 74 48 63 59 C47 77 22 56 33 34 C41 19 65 19 78 35" stroke="#fff0ce" stroke-width="9"/>
  <path d="M54 45 C50 53 43 47 46 40" stroke="#a3d9c6" stroke-width="7"/>
  <path d="M29 23 Q39 15 50 14" stroke="#fff5fa" stroke-width="4"/>
  <path d="M65 82 Q50 72 48 89 Q58 96 66 85 Q67 102 83 98 Q85 87 65 82Z" fill="#9ddac3" stroke-width="2.5"/>
  <circle cx="65" cy="85" r="4" fill="#eac96c" stroke-width="2"/>`;

const wrappedCandy = `
  <path d="M34 46 15 30 11 56 18 72 37 66 M84 46 103 31 109 55 102 73 82 65" fill="#a6dac8"/>
  <path d="M16 43 32 55 17 62 M102 43 88 55 104 63" stroke="#60a992" stroke-width="2.5"/>
  <rect x="29" y="35" width="62" height="47" rx="19" transform="rotate(-10 60 58)" fill="#f4b2cf"/>
  <path d="M38 39 62 79 M54 35 79 76 M72 36 88 61" stroke="#fff0d5" stroke-width="10"/>
  <rect x="29" y="35" width="62" height="47" rx="19" transform="rotate(-10 60 58)" fill="none"/>
  <path d="M39 43 45 41" stroke="#fff5fa" stroke-width="4"/>
  <path d="M28 92 31 97 M92 19 95 25 M83 99 88 95" stroke="#dc9cbd" stroke-width="3"/>`;

const iceCream = `
  <path d="M36 61 59 109 Q61 113 63 109 L86 61Z" fill="#ecc385"/>
  <path d="M41 72 68 98 M50 64 77 88 M79 71 52 97 M69 64 44 87" stroke="#c49358" stroke-width="2.5"/>
  <path d="M29 56 Q27 35 45 32 Q51 19 67 24 Q88 27 89 45 Q101 51 92 64 Q84 72 77 64 Q69 73 60 65 Q50 74 43 65 Q30 73 26 64 Q23 59 29 56Z" fill="#f5b8d0"/>
  <path d="M34 50 Q42 42 50 49 M68 40 Q76 34 82 42" stroke="#ffe8ef" stroke-width="4"/>
  <circle cx="62" cy="19" r="9" fill="#da7599"/>
  <path d="M62 11 Q62 5 71 7" stroke="#60946a" stroke-width="3"/>
  <path d="M39 39 43 42 M59 34 57 39 M76 53 80 55 M51 58 54 54" stroke="#6cae99" stroke-width="3"/>`;

const candyCastle = `
  <path d="M18 105V54 H40V103 M80 103V54 H102V105" fill="#f5c8da"/>
  <path d="M15 55 29 28 43 55Z M77 55 91 28 105 55Z" fill="#9bd7c2"/>
  <path d="M38 103V39 H82V103Z" fill="#f2b1cf"/>
  <path d="M33 41 60 12 87 41Z" fill="#d696c2"/>
  <path d="M43 30 71 30 M20 46H38 M82 46H100" stroke="#fff0cf" stroke-width="5"/>
  <path d="M51 104V84 a9 9 0 0 1 18 0 V104" fill="#aa6d93"/>
  <path d="M23 69H35 M23 82H35 M85 69H97 M85 82H97" stroke="#fff4e5" stroke-width="5"/>
  <rect x="52" y="48" width="16" height="20" rx="8" fill="#a5dece" stroke-width="2.5"/>
  <path d="M60 50V66 M54 58H66" stroke="#fff5e5" stroke-width="2.5"/>
  <path d="M14 105H106" stroke="#95704f" stroke-width="4"/>
  <circle cx="29" cy="27" r="4" fill="#e7b95f" stroke-width="2"/>
  <circle cx="91" cy="27" r="4" fill="#e7b95f" stroke-width="2"/>
  <circle cx="60" cy="11" r="4" fill="#e7b95f" stroke-width="2"/>`;

const themes = {
  jungle: {
    name: 'Jungle', dark: '#39744b', bright: '#9ac56b', highlight: '#ebbe68', background: '#edf7df',
    symbol: explorerHat,
    medals: [
      ['Monkey', animals.monkey],
      ['Tree Frog', `<path d="M19 88 Q15 55 47 46 Q80 45 105 18 Q103 90 65 103 Q34 109 19 88Z" fill="#c1dfa0" stroke="#79a665" stroke-width="2"/><g transform="translate(4 -3) scale(.94)">${animals.frog}</g>`],
      ['Tiger', animals.tiger],
      ['Elephant', growing.elephant],
      ['Bamboo', growing.bamboo],
      ['Waterfall', growing.waterfall]
    ]
  },
  candy: {
    name: 'Candy', dark: '#a4527e', bright: '#f2aecf', highlight: '#9bd7c2', background: '#fff0f7',
    symbol: candyCastle,
    medals: [
      ['Party Cake', food.cake], ['Cookie', food.cookie], ['Lollipop', lollipop],
      ['Wrapped Candy', wrappedCandy], ['Ice Cream', iceCream], ['Candy Castle', candyCastle]
    ]
  }
};

function svg(title, shapes, background) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120" role="img" aria-labelledby="title">
  <title id="title">${title}</title>
  <circle cx="60" cy="60" r="55" fill="${background}"/>
  <g fill="none" stroke="#765445" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">${shapes}
  </g>
</svg>
`;
}

function createRewardImages() {
  const outputs = [];
  for (const [id, theme] of Object.entries(themes)) {
    outputs.push([`assets/images/rewards/${id}.svg`, svg(`${theme.name} world`, theme.symbol, theme.background)]);
    theme.medals.forEach(([name, art], index) => {
      const edge = id === 'jungle'
        ? `<path d="M15 42 Q7 61 17 78 M105 42 Q113 61 103 78" stroke="${theme.dark}" stroke-width="3"/>
    <path d="M13 52 8 44 M13 63 7 59 M15 73 9 73 M107 52 112 44 M107 63 113 59 M105 73 111 73" stroke="${theme.dark}" stroke-width="3"/>`
        : Array.from({ length: 12 }, (_, mark) => `<path d="M58 13 62 18" transform="rotate(${mark * 30} 60 60)" stroke="${mark % 2 ? '#fff3da' : theme.highlight}" stroke-width="3"/>`).join('\n    ');
      const shapes = `<circle cx="60" cy="60" r="49" fill="${theme.bright}" stroke="${theme.dark}" stroke-width="3"/>
    <circle cx="60" cy="60" r="42" fill="${theme.background}" stroke="${theme.highlight}" stroke-width="2.5"/>
    ${edge}
    <g transform="translate(18 16) scale(.7)">${art}</g>
    <path d="M42 101 48 116 60 110 72 116 78 101" fill="${theme.highlight}" stroke="${theme.dark}" stroke-width="2.5"/>`;
      outputs.push([`assets/images/rewards/${id}-${index + 1}.svg`, svg(`${theme.name}: ${name}`, shapes, theme.background)]);
    });
  }
  return outputs;
}

if (require.main === module) {
  const root = path.resolve(__dirname, '../..');
  for (const [relativePath, content] of createRewardImages()) {
    const filename = path.join(root, relativePath);
    if (fs.existsSync(filename) && fs.readFileSync(filename, 'utf8').replace(/\r\n/g, '\n') === content) continue;
    fs.writeFileSync(filename, content, 'utf8');
  }
  console.log('Generated 14 Jungle and Candy reward SVGs.');
}

module.exports = { createRewardImages };
