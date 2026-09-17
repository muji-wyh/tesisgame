// A gold ring and pointer distinguish the named part from its supporting limb.
function focus(x, y, radius) {
  return `<circle cx="${x}" cy="${y}" r="${radius}" fill="none" stroke="#e9ad45" stroke-width="3"/>
    <path d="M${x + radius + 22} ${y}H${x + radius + 6} m6 -6 -6 6 6 6" fill="none" stroke="#dca83d" stroke-width="3"/>`;
}

const octopusArms = 'M43 63 Q29 72 18 62 Q11 57 17 52 M42 72 Q27 88 16 79 M46 79 Q33 102 25 94 M54 82 Q48 107 42 103 M66 82 Q72 107 78 103 M74 79 Q87 102 95 94 M78 72 Q93 88 104 79 M77 63 Q91 72 102 62 Q109 57 103 52';

module.exports = {
  elephant: `
    <ellipse cx="60" cy="106" rx="43" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M86 59 Q102 62 101 81 M100 77 105 85" stroke="#95afb9" stroke-width="4"/>
    <path d="M29 53 Q33 34 65 36 Q93 38 94 64 V97 Q93 103 81 101 L78 80 H63 L61 100 H48 L47 79 H37Z" fill="#b3c5cc"/>
    <path d="M41 77V100 H29V79" fill="#a2b9c3"/>
    <path d="M51 35 Q30 21 18 41 Q10 57 19 71 V87 Q18 94 12 88 Q8 92 12 98 Q29 110 32 90 L33 70 Q47 69 52 54Z" fill="#b3c5cc"/>
    <path d="M40 35 Q64 27 66 54 Q64 80 45 71 Q37 67 40 35Z" fill="#c7d5d9"/>
    <path d="M48 41 Q60 42 58 59" stroke="#e0e7e8" stroke-width="4"/>
    <circle cx="25" cy="49" r="3" fill="#765445" stroke="none"/>
    <path d="M24 65 Q27 69 32 66 M17 80H24 M15 89H23 M32 97V101 M37 97V101 M52 97V101 M85 97V101" stroke-width="2"/>
    <path d="M31 68 Q39 67 40 60 Q41 76 32 76Z" fill="#fff1d9" stroke-width="2"/>`,

  giraffe: `
    <ellipse cx="62" cy="108" rx="34" ry="3" fill="#eadbc5" stroke="none"/>
    <path d="M78 65 Q95 63 94 81 M94 78 98 86" stroke-width="3"/>
    <path d="M45 51 46 28 63 26 64 62 Q86 56 89 75 L85 104 H77 L76 85 H59 L57 104 H49 L48 83 H40 L37 103 H29 L33 72Z" fill="#efc979"/>
    <path d="M46 31 37 24 39 19 49 23 M62 25 73 18 78 23 67 33" fill="#efc979" stroke-width="2.5"/>
    <path d="M52 21 50 11 M62 21 63 11" stroke-width="3"/>
    <circle cx="50" cy="10" r="3" fill="#a77c59" stroke="none"/><circle cx="63" cy="10" r="3" fill="#a77c59" stroke="none"/>
    <path d="M44 30 Q40 18 55 18 Q69 19 68 31 L72 36 Q68 46 55 42 L45 39Z" fill="#f3d899"/>
    <ellipse cx="61" cy="38" rx="12" ry="6" fill="#e3bd78" stroke-width="2"/>
    <circle cx="51" cy="29" r="2.5" fill="#765445" stroke="none"/>
    <path d="M63 38H64 M57 50 61 50 60 57 54 57Z M46 65 51 62 56 68 51 74 45 71Z M64 70 71 66 75 72 72 79 65 77Z M79 64 84 68 82 73 77 70Z" fill="#bd875e" stroke="none"/>
    <path d="M31 99H38 M49 100H57 M78 100H85" stroke="#a77c59" stroke-width="3"/>`,

  kangaroo: `
    <ellipse cx="60" cy="108" rx="44" ry="3" fill="#eadbc5" stroke="none"/>
    <path d="M48 77 Q27 96 12 95 Q20 108 54 96" fill="#c79371"/>
    <path d="M58 49 Q40 66 46 86 Q48 96 65 96 L58 103 H91 Q100 96 85 94 L74 83 76 62Z" fill="#d8a67d"/>
    <path d="M56 62 Q71 60 73 80 Q62 91 54 78Z" fill="#f3d4af" stroke-width="2.5"/>
    <path d="M53 75 Q60 68 70 75 Q69 87 61 87 Q54 84 53 75Z" fill="#e7bb94" stroke-width="2.5"/>
    <path d="M65 49 67 36 Q65 28 70 25 L67 11 Q71 5 75 13 L81 29 88 12 Q94 8 94 16 L89 35 101 39 Q106 45 99 49 L87 49 78 62Z" fill="#d8a67d"/>
    <path d="M74 15 79 30 M90 18 85 33" stroke="#efbd9d" stroke-width="3"/>
    <circle cx="84" cy="39" r="2.5" fill="#765445" stroke="none"/>
    <circle cx="101" cy="42" r="3" fill="#765445" stroke="none"/>
    <path d="M85 48 Q89 52 95 48 M73 61 88 67 92 64 M61 92 72 94" stroke-width="2.5"/>`,

  penguin: `
    <ellipse cx="60" cy="107" rx="34" ry="4" fill="#d1e7e7" stroke="none"/>
    <path d="M38 99 26 106 53 107 54 99 M67 99 67 107 94 106 82 99" fill="#efb660"/>
    <path d="M34 51 Q14 61 20 89 Q30 86 39 72 M86 51 Q106 61 100 89 Q90 86 81 72" fill="#6d7988"/>
    <path d="M30 67 Q26 20 60 18 Q94 20 90 67 Q100 101 60 103 Q20 101 30 67Z" fill="#6d7988"/>
    <path d="M39 41 Q48 32 60 46 Q72 32 81 41 Q85 55 78 64 Q97 94 60 96 Q23 94 42 64 Q35 55 39 41Z" fill="#fff7e6" stroke="none"/>
    <circle cx="46" cy="48" r="3" fill="#765445" stroke="none"/><circle cx="74" cy="48" r="3" fill="#765445" stroke="none"/>
    <path d="M51 59 60 54 69 59 60 67Z" fill="#f0bc72" stroke-width="2.5"/>
    <ellipse cx="39" cy="60" rx="5" ry="3" fill="#f4c2b3" stroke="none"/><ellipse cx="81" cy="60" rx="5" ry="3" fill="#f4c2b3" stroke="none"/>`,

  squirrel: `
    <ellipse cx="60" cy="107" rx="39" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M65 92 Q97 99 102 71 Q114 39 94 22 Q78 8 67 21 Q54 39 76 48 Q91 51 86 66 Q83 76 70 71Z" fill="#c79371"/>
    <path d="M82 29 Q100 36 97 58 Q96 78 82 84" stroke="#edcda3" stroke-width="5"/>
    <path d="M39 58 Q32 80 40 96 L29 104 H67 Q81 99 76 87 L68 61Z" fill="#d8a67d"/>
    <path d="M44 67 Q62 63 66 81 Q66 95 50 93Z" fill="#f3d4af" stroke="none"/>
    <path d="M30 38 29 18 Q35 12 44 31 L57 21 Q66 15 65 38 Q77 54 63 62 Q44 72 29 59 L18 55 Q13 48 23 45Z" fill="#d8a67d"/>
    <path d="M35 24 40 34 M60 27 57 38" stroke="#efbd9d" stroke-width="3"/>
    <circle cx="39" cy="45" r="3" fill="#765445" stroke="none"/>
    <circle cx="18" cy="49" r="3" fill="#765445" stroke="none"/>
    <path d="M26 56 Q31 61 36 56 M45 72 34 80 M61 69 54 77" stroke-width="2.5"/>
    <path d="M30 82 Q30 99 41 101 Q52 93 50 82Z" fill="#b58b69" stroke-width="2.5"/>
    <path d="M27 82 Q28 70 40 71 Q53 71 53 82Z" fill="#93785d" stroke-width="2.5"/>
    <path d="M40 72V67" stroke-width="2.5"/>`,

  pumpkin: `
    <ellipse cx="60" cy="106" rx="40" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M56 37 53 22 Q53 16 63 16 L69 21 65 37" fill="#91bd7e"/>
    <path d="M65 30 Q80 17 91 25 Q96 34 87 35 Q80 35 85 29" stroke="#78ad72" stroke-width="2.5"/>
    <path d="M60 37 Q42 27 28 40 Q10 41 15 70 Q17 100 38 98 Q59 109 81 98 Q103 99 106 70 Q111 42 91 40 Q77 27 60 37Z" fill="#ee9c54"/>
    <ellipse cx="60" cy="69" rx="21" ry="34" fill="#f2ad60"/>
    <path d="M37 39 Q18 65 36 96 M83 39 Q102 65 84 96 M61 40 Q50 57 53 87" stroke="#d98248" stroke-width="2.5"/>
    <path d="M45 44 Q36 58 37 70" stroke="#ffd292" stroke-width="4"/>`,

  coconut: `
    <ellipse cx="60" cy="105" rx="42" ry="4" fill="#eadbc5" stroke="none"/>
    <circle cx="72" cy="52" r="32" fill="#b58b69"/>
    <path d="M61 24 Q44 40 48 60 M88 30 95 43 M82 74 91 65 M69 22 73 27 M99 54 94 61" stroke="#93785d" stroke-width="2.5"/>
    <circle cx="77" cy="42" r="3" fill="#765445" stroke="none"/><circle cx="87" cy="44" r="3" fill="#765445" stroke="none"/><circle cx="81" cy="52" r="3" fill="#765445" stroke="none"/>
    <path d="M15 68 Q46 44 78 68 Q78 99 48 103 Q17 99 15 68Z" fill="#ab8465"/>
    <ellipse cx="47" cy="68" rx="32" ry="21" fill="#fff7e6"/>
    <ellipse cx="47" cy="68" rx="20" ry="12" fill="#e7d8b8" stroke="#c8b7a0" stroke-width="2"/>
    <path d="M24 87 31 94 M39 96 40 100 M64 88 60 95 M26 61 Q36 52 48 53" stroke="#e9c291" stroke-width="3"/>`,

  pineapple: `
    <ellipse cx="60" cy="107" rx="31" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M47 44 28 25 Q45 24 53 36 L44 10 Q58 18 61 33 L69 9 Q77 22 69 36 L90 21 Q89 37 74 47Z" fill="#91bd7e"/>
    <path d="M51 40 41 30 M60 40 58 25 M68 41 78 30" stroke="#699a65" stroke-width="2.5"/>
    <path d="M60 40 Q84 37 89 61 L87 84 Q84 105 60 106 Q36 105 33 84 L31 61 Q36 37 60 40Z" fill="#f4d36a"/>
    <path d="M34 54 80 99 M44 44 87 85 M62 41 89 67 M32 72 65 105 M40 95 82 50 M32 80 68 42 M34 59 46 44 M55 105 87 74" stroke="#d5a94d" stroke-width="2"/>
    <path d="M44 62 47 66 50 62 M57 76 60 80 63 76 M70 62 73 66 76 62 M44 88 47 92 50 88 M70 88 73 92 76 88" stroke="#b78e5b" stroke-width="1.8"/>
    <path d="M39 54 Q43 46 51 45" stroke="#fff0a2" stroke-width="4"/>`,

  watermelon: `
    <ellipse cx="59" cy="103" rx="45" ry="5" fill="#eadbc5" stroke="none"/>
    <ellipse cx="55" cy="61" rx="43" ry="33" fill="#91c17c"/>
    <path d="M31 36 Q13 61 31 87 M46 30 Q29 59 46 93 M62 29 Q47 60 63 93 M77 33 Q68 46 68 59" stroke="#699a65" stroke-width="6"/>
    <path d="M21 58 Q21 46 30 41" stroke="#dceba1" stroke-width="4"/>
    <ellipse cx="83" cy="72" rx="24" ry="31" fill="#7fbd73"/>
    <ellipse cx="83" cy="72" rx="19" ry="26" fill="#eef2ae" stroke="none"/>
    <ellipse cx="83" cy="72" rx="15" ry="23" fill="#ef7f78" stroke="none"/>
    <path d="M80 56 79 61 M89 61 89 66 M76 69 75 73 M84 76 84 81 M92 80 92 84 M78 85 79 89" stroke="#765445" stroke-width="2.5"/>`,

  strawberry: `
    <ellipse cx="60" cy="108" rx="27" ry="3" fill="#eadbc5" stroke="none"/>
    <path d="M60 36 Q81 23 96 42 Q110 61 83 89 Q69 106 60 108 Q51 106 37 89 Q10 61 24 42 Q39 23 60 36Z" fill="#e97870"/>
    <path d="M60 35 42 21 44 36 25 35 40 47 53 41 60 52 67 41 80 47 95 35 76 36 78 21Z" fill="#91bd7e" stroke-width="2.5"/>
    <path d="M60 35 Q55 22 63 13" stroke="#699a65" stroke-width="4"/>
    <path d="M33 52 35 58 M48 58 50 64 M68 57 67 63 M86 52 84 58 M40 73 43 78" stroke="#f8e4af" stroke-width="3"/>
    <path d="M59 71 59 77 M77 72 74 78 M51 88 54 93 M68 87 65 93" stroke="#f8e4af" stroke-width="3"/>
    <path d="M31 44 Q25 50 27 57" stroke="#ffc0ae" stroke-width="4"/>`,

  river: `
    <path d="M13 53 Q26 36 44 44 L59 34 77 45 Q98 39 108 53 V93 Q61 119 13 95Z" fill="#acd18e" stroke="none"/>
    <path d="M56 41 Q85 49 65 59 Q42 69 55 78 Q74 88 99 103 Q79 112 53 108 Q39 91 25 84 Q12 67 40 57 Q68 50 50 43Z" fill="#9fdbe5" stroke="#83adbe" stroke-width="2.5"/>
    <path d="M38 70 Q29 77 48 85 M61 93 78 102 M56 50 Q65 53 49 59" stroke="#e8f4ef" stroke-width="3"/>
    <path d="M17 43 29 26 41 43Z M79 37 90 20 103 38Z" fill="#8fbd79" stroke-width="2.5"/>
    <path d="M29 43V53 M90 38V47" stroke="#a77c59" stroke-width="3"/>`,

  lake: `
    <path d="M15 53 36 27 51 45 70 22 103 53Z" fill="#b3c5cc" stroke-width="2.5"/>
    <path d="M28 37 36 27 43 37 37 35Z M60 35 70 22 81 37 70 33Z" fill="#fff7e6" stroke="none"/>
    <path d="M14 55 Q40 45 65 51 Q90 43 107 57 L108 89 Q61 113 12 90Z" fill="#acd18e" stroke="none"/>
    <path d="M15 67 Q28 52 60 56 Q95 54 106 70 Q113 86 88 96 Q57 106 28 94 Q8 86 15 67Z" fill="#9ec9e0" stroke="#83adbe" stroke-width="2.5"/>
    <path d="M29 68 Q56 60 90 67 M22 81H43 M74 80H99 M39 91H77" stroke="#d6edef" stroke-width="3"/>
    <path d="M53 73H73L68 79H59Z" fill="#d99d69" stroke-width="2"/>
    <path d="M63 72V60L71 71H63Z" fill="#fff1d9" stroke-width="2"/>`,

  mountain: `
    <ellipse cx="60" cy="105" rx="46" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M12 101 57 16 Q60 10 64 16 L108 101Z" fill="#9abcca"/>
    <path d="M61 17 77 99H108Z" fill="#7f9eaf" stroke="none"/>
    <path d="M39 50 57 16 Q60 10 64 16 L84 55 69 46 62 56 53 43 45 52Z" fill="#fff7e6"/>
    <path d="M26 89 35 73 M90 92 84 79 M49 88 56 65" stroke="#c5d6db" stroke-width="3"/>
    <path d="M13 102H108 M43 101 49 94 56 101 M78 101 82 96 88 101" stroke="#a77c59" stroke-width="2.5"/>`,

  rainbow: `
    <path d="M17 78 A43 43 0 0 1 103 78" stroke="#e97870" stroke-width="9"/>
    <path d="M25 78 A35 35 0 0 1 95 78" stroke="#ee9c54" stroke-width="8"/>
    <path d="M32 78 A28 28 0 0 1 88 78" stroke="#f4d36a" stroke-width="7"/>
    <path d="M38 78 A22 22 0 0 1 82 78" stroke="#91bd7e" stroke-width="6"/>
    <path d="M44 78 A16 16 0 0 1 76 78" stroke="#85bfda" stroke-width="6"/>
    <path d="M50 78 A10 10 0 0 1 70 78" stroke="#b999bd" stroke-width="6"/>
    <path d="M15 89 Q7 87 12 78 Q15 74 21 77 Q21 62 33 65 Q43 66 42 77 Q54 73 55 85 Q56 94 43 94 H23Z M76 94 Q63 95 64 85 Q65 75 77 78 Q76 64 89 66 Q100 64 100 77 Q110 75 111 85 Q113 94 101 94Z" fill="#fffdf5" stroke="#b4c9cd" stroke-width="2.5"/>`,

  waterfall: `
    <path d="M19 33 40 20H80L101 36 99 91H20Z" fill="#a29c91"/>
    <path d="M19 32 28 23 42 23 47 18 80 20 94 28 102 39 79 38 40 38Z" fill="#91bd7e" stroke-width="2.5"/>
    <path d="M21 49 36 45 31 63 21 65 M81 49 97 56 M86 59 79 72 98 77 M24 77 37 72" stroke="#c8b7a0" stroke-width="3"/>
    <ellipse cx="60" cy="96" rx="46" ry="13" fill="#9fdbe5" stroke="#83adbe" stroke-width="2.5"/>
    <path d="M43 31 Q60 27 77 31 L79 72 Q78 84 90 94 Q62 109 31 95 Q44 83 41 70Z" fill="#9fdbe5" stroke="#83adbe" stroke-width="2.5"/>
    <path d="M49 38V72 Q49 87 42 93 M60 35V84 M70 41V71 Q69 85 76 91" stroke="#e8f4ef" stroke-width="4"/>
    <path d="M29 96 Q34 87 43 94 Q49 84 57 95 Q66 86 72 95 Q80 89 87 98 M24 102H41 M80 104H96" stroke="#eef9fb" stroke-width="3"/>`,

  helmet: `
    <ellipse cx="60" cy="108" rx="32" ry="3" fill="#eadbc5" stroke="none"/>
    <path d="M30 64 49 94 Q57 104 67 96 L87 66 M49 64 52 94 M74 62 65 96" stroke="#8b8e9d" stroke-width="5"/>
    <rect x="52" y="93" width="13" height="9" rx="3" fill="#d4dce1" stroke-width="2"/>
    <path d="M19 64 Q16 25 55 21 Q92 14 103 52 L106 65 94 71 20 71Z" fill="#85bfda"/>
    <path d="M20 64 Q55 72 98 56 L106 65 94 73 23 75Z" fill="#6c9ab7" stroke-width="2.5"/>
    <path d="M36 33 Q44 28 49 30 L44 46 34 47Z M60 27 69 28 70 43 59 45Z M80 32 88 38 92 49 82 49Z" fill="#6d7988" stroke-width="2"/>
    <path d="M27 49 26 55" stroke="#d3edf0" stroke-width="4"/>`,

  sweater: `
    <path d="M41 24 50 20 Q60 29 70 20 L79 24 103 50 99 98 84 97 82 69 84 103H36L38 69 36 97 21 98 17 50Z" fill="#b999bd"/>
    <path d="M50 20 Q50 39 60 39 Q70 39 70 20 M36 92H84 M20 87 37 86 M83 86 100 87" stroke="#927d99" stroke-width="3"/>
    <path d="M41 97V102 M49 96V102 M57 96V102 M65 96V102 M73 96V102 M81 96V102 M26 90V97 M32 89V96 M88 89V96 M94 90V97" stroke="#dfc6df" stroke-width="2"/>
    <path d="M43 49 47 53 51 49 M56 49 60 53 64 49 M69 49 73 53 77 49 M43 64 47 68 51 64 M56 64 60 68 64 64 M69 64 73 68 77 64 M43 79 47 83 51 79 M56 79 60 83 64 79 M69 79 73 83 77 79" stroke="#dfc6df" stroke-width="2.5"/>
    <path d="M39 32 27 48" stroke="#ecd8e8" stroke-width="4"/>`,

  necklace: `
    <path d="M60 18 Q31 12 26 43 Q25 74 54 88 M60 18 Q89 12 94 43 Q95 74 66 88" stroke="#d5a862" stroke-width="5"/>
    <path d="M60 18 Q31 12 26 43 Q25 74 54 88 M60 18 Q89 12 94 43 Q95 74 66 88" stroke="#fff0b3" stroke-width="2" stroke-dasharray="3 7"/>
    <rect x="53" y="14" width="14" height="7" rx="3" fill="#edc779" stroke-width="2"/>
    <circle cx="60" cy="84" r="6" fill="#edc779" stroke-width="2.5"/>
    <path d="M60 87 75 96 60 111 45 96Z" fill="#a9d9df"/>
    <path d="M45 96H75 M60 87 54 96 60 111 66 96Z" stroke="#739ba9" stroke-width="2"/>
    <path d="M20 68V76 M16 72H24 M98 82V92 M93 87H103" stroke="#d5b873" stroke-width="2.5"/>`,

  bracelet: `
    <path d="M15 50 Q51 54 79 44 L106 51V81L80 86 Q48 77 15 82Z" fill="#f3d4af" stroke="#c8a078" stroke-width="2.5"/>
    <ellipse cx="61" cy="65" rx="20" ry="30" fill="none" stroke="#d5a862" stroke-width="4"/>
    ${Array.from({ length: 10 }, (_, index) => {
      const angle = index * Math.PI / 5;
      const colors = ['#a9d9df', '#db9dac', '#efc979', '#b999bd', '#91bd7e'];
      return `<circle cx="${(61 + Math.cos(angle) * 20).toFixed(2)}" cy="${(65 + Math.sin(angle) * 30).toFixed(2)}" r="7" fill="${colors[index % colors.length]}" stroke-width="2.5"/>`;
    }).join('\n    ')}
    <path d="M35 33V43 M30 38H40" stroke="#d5b873" stroke-width="2.5"/>`,

  sunglasses: `
    <path d="M15 53 23 31 40 37 M105 53 97 31 80 37" stroke="#9b7058" stroke-width="5"/>
    <path d="M17 49 Q34 42 51 50 L48 76 Q32 88 18 76 L12 54Z M69 50 Q86 42 103 49 L108 54 102 76 Q88 88 72 76Z" fill="#6d7988" stroke-width="5"/>
    <path d="M50 54 Q60 49 70 54 M12 53H18 M102 53H108" stroke-width="5"/>
    <path d="M24 58 34 53 M24 68 42 56 M80 59 89 54 M81 69 98 57" stroke="#b9cbd7" stroke-width="3"/>`,

  scooter: `
    <ellipse cx="62" cy="108" rx="43" ry="3" fill="#eadbc5" stroke="none"/>
    <path d="M34 89H72L88 72 87 27" stroke="#6c9ab7" stroke-width="7"/>
    <path d="M74 26H100" stroke-width="6"/>
    <path d="M77 26H84 M94 26H101" stroke="#ef9a84" stroke-width="7"/>
    <path d="M89 60 97 94" stroke="#9ec9e0" stroke-width="6"/>
    <path d="M22 87H64L70 94H22Z" fill="#ef9a84" stroke-width="2.5"/>
    <circle cx="27" cy="98" r="10" fill="#6d6866"/><circle cx="97" cy="98" r="10" fill="#6d6866"/>
    <circle cx="27" cy="98" r="4" fill="#f8ead3" stroke="none"/><circle cx="97" cy="98" r="4" fill="#f8ead3" stroke="none"/>
    <path d="M81 37H89" stroke="#d3edf0" stroke-width="3"/>`,

  tractor: `
    <ellipse cx="60" cy="108" rx="46" ry="3" fill="#eadbc5" stroke="none"/>
    <path d="M30 34H62V71H28Z" fill="#91bd7e"/>
    <path d="M35 39H55V64H35Z" fill="#d3edf0" stroke-width="2.5"/>
    <path d="M27 31H65" stroke="#699a65" stroke-width="6"/>
    <path d="M61 57H93Q100 57 101 67V86H51V71Z" fill="#91bd7e"/>
    <path d="M81 57V37H89" stroke="#6d6866" stroke-width="6"/>
    <path d="M14 76 Q33 51 53 76" fill="#acd18e" stroke-width="3"/>
    <path d="M76 65V76 M83 65V76 M90 65V76" stroke="#699a65" stroke-width="2.5"/>
    <circle cx="34" cy="86" r="22" fill="#6d6866"/><circle cx="92" cy="94" r="13" fill="#6d6866"/>
    <circle cx="34" cy="86" r="12" fill="#edc779"/><circle cx="92" cy="94" r="6" fill="#edc779"/>
    <path d="M34 67V72 M15 86H20 M34 100V105 M48 86H53 M21 73 25 77 M44 96 48 100 M21 100 25 96 M44 77 48 73" stroke="#a29c91" stroke-width="2.5"/>`,

  ambulance: `
    <ellipse cx="60" cy="106" rx="46" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M14 41 Q14 35 20 35H74L94 53 106 60V91H14Z" fill="#fff7e6"/>
    <path d="M70 43H73L90 58H70Z" fill="#9ec9e0" stroke-width="2.5"/>
    <path d="M15 77H104" stroke="#ef9a84" stroke-width="8"/>
    <path d="M66 38V87 M74 66H80" stroke-width="2.5"/>
    <rect x="43" y="26" width="18" height="9" rx="3" fill="#e97870" stroke-width="2.5"/>
    <path d="M35 52H43V44H51V52H59V60H51V68H43V60H35Z" fill="#85bfda" stroke="#6c9ab7" stroke-width="2"/>
    <rect x="98" y="64" width="8" height="8" rx="2" fill="#ffe49a" stroke-width="2"/>
    <circle cx="34" cy="92" r="12" fill="#6d6866"/><circle cx="87" cy="92" r="12" fill="#6d6866"/>
    <circle cx="34" cy="92" r="5" fill="#f8ead3" stroke="none"/><circle cx="87" cy="92" r="5" fill="#f8ead3" stroke="none"/>`,

  helicopter: `
    <path d="M45 89 42 100 M81 89 85 100 M29 100H101Q106 100 108 95" stroke="#8b8e9d" stroke-width="4"/>
    <path d="M20 49 51 60 51 77 19 62 12 40H22Z" fill="#ef9a84"/>
    <path d="M48 55 Q54 36 78 40 Q101 43 105 67 Q106 87 85 91H58Q40 88 40 70Q39 60 48 55Z" fill="#ef9a84"/>
    <path d="M72 45 Q96 45 99 65H72Z" fill="#d3edf0" stroke-width="2.5"/>
    <rect x="51" y="53" width="14" height="16" rx="3" fill="#d3edf0" stroke-width="2.5"/>
    <path d="M69 74V85 M76 76H83 M65 39V25 M16 24H109" stroke-width="3.5"/>
    <path d="M31 18H91" stroke="#c7d5d9" stroke-width="3"/>
    <circle cx="19" cy="52" r="11" fill="#fff7e6" stroke-width="2.5"/>
    <path d="M12 45 26 59 M12 59 26 45" stroke="#8b8e9d" stroke-width="3"/>
    <circle cx="19" cy="52" r="3" fill="#765445" stroke="none"/>`,

  submarine: `
    <path d="M61 45V28Q61 21 68 21H79V30H70V45Z" fill="#efc979"/>
    <rect x="76" y="18" width="8" height="15" rx="3" fill="#b3c5cc" stroke-width="2.5"/>
    <path d="M18 66H9 M10 53V80" stroke="#a77c59" stroke-width="5"/>
    <path d="M14 49 35 57V77L14 84Z" fill="#efb660"/>
    <rect x="22" y="42" width="85" height="49" rx="24" fill="#efc979"/>
    <path d="M42 82H87" stroke="#d5a862" stroke-width="3"/>
    <circle cx="43" cy="65" r="10" fill="#9ec9e0"/><circle cx="68" cy="65" r="10" fill="#9ec9e0"/><circle cx="92" cy="65" r="8" fill="#9ec9e0"/>
    <path d="M39 62 43 58 M64 62 68 58 M89 62 92 60" stroke="#e8f4ef" stroke-width="3"/>
    <circle cx="99" cy="27" r="5" stroke="#9bc9d5" stroke-width="2.5"/>
    <circle cx="109" cy="15" r="3" fill="#c7e6e6" stroke="none"/>
    <path d="M27 103H49 M79 103H100" stroke="#a5d8df" stroke-width="2.5"/>`,

  robot: `
    <path d="M44 91V104H32 M76 91V104H88" stroke="#8b8e9d" stroke-width="8"/>
    <path d="M35 68H23V85 M85 68H97V85" stroke="#8b8e9d" stroke-width="7"/>
    <path d="M18 93V86Q23 80 28 86V93 M92 93V86Q97 80 102 86V93" stroke="#a2b9c3" stroke-width="4"/>
    <rect x="34" y="57" width="52" height="37" rx="8" fill="#b3c5cc"/>
    <rect x="27" y="23" width="66" height="38" rx="10" fill="#9ec9e0"/>
    <path d="M60 23V14" stroke-width="3"/>
    <circle cx="60" cy="11" r="5" fill="#ef9a84" stroke-width="2.5"/>
    <rect x="19" y="34" width="8" height="15" rx="3" fill="#edc779" stroke-width="2"/>
    <rect x="93" y="34" width="8" height="15" rx="3" fill="#edc779" stroke-width="2"/>
    <circle cx="44" cy="39" r="5" fill="#fff7e6"/><circle cx="76" cy="39" r="5" fill="#fff7e6"/>
    <circle cx="44" cy="39" r="2" fill="#765445" stroke="none"/><circle cx="76" cy="39" r="2" fill="#765445" stroke="none"/>
    <path d="M47 50Q60 58 73 50" stroke-width="2.5"/>
    <rect x="43" y="68" width="23" height="16" rx="3" fill="#fff1d9" stroke-width="2"/>
    <path d="M47 77H51L54 72 57 81 60 77H63" stroke="#91bd7e" stroke-width="2"/>
    <circle cx="75" cy="72" r="3" fill="#ef9a84" stroke="none"/><circle cx="75" cy="82" r="3" fill="#efc979" stroke="none"/>`,

  puzzle: `
    <path d="M18 42H58V55Q45 50 45 61Q45 72 58 67V82H44Q49 69 38 69Q27 69 32 82H18Z" fill="#9ec9e0" stroke-width="2.5"/>
    <path d="M18 82H32Q27 69 38 69Q49 69 44 82H58V95Q71 90 71 101Q71 112 58 107V110H18Z" fill="#91bd7e" stroke-width="2.5"/>
    <path d="M58 82H72Q67 69 78 69Q89 69 84 82H98V110H58V107Q71 112 71 101Q71 90 58 95Z" fill="#efc979" stroke-width="2.5"/>
    <g transform="rotate(13 81 38)">
      <path d="M62 17H102V57H88Q93 44 82 44Q71 44 76 57H62V43Q49 48 49 37Q49 26 62 31Z" fill="#ef9a84" stroke-width="2.5"/>
      <path d="M70 24H94" stroke="#ffd0b7" stroke-width="3"/>
    </g>`,

  marble: `
    <ellipse cx="51" cy="102" rx="36" ry="5" fill="#eadbc5" stroke="none"/>
    <circle cx="51" cy="60" r="35" fill="#d3edf0"/>
    <path d="M29 38 Q73 29 61 60 Q48 79 73 87 Q49 94 37 80 Q27 68 44 55 Q54 45 29 38Z" fill="#85bfda" stroke="none"/>
    <path d="M29 38 Q64 44 48 59 Q35 75 51 89 Q29 79 34 65 Q43 52 29 38Z" fill="#91bd7e" stroke="none"/>
    <path d="M46 40 Q65 44 57 57 Q44 70 57 82" stroke="#ef9a84" stroke-width="5"/>
    <path d="M25 49 Q29 37 40 33" stroke="#ffffff" stroke-width="5"/>
    <circle cx="27" cy="60" r="3" fill="#ffffff" stroke="none"/>
    <circle cx="93" cy="93" r="14" fill="#d3edf0" stroke-width="2.5"/>
    <path d="M87 82 Q102 91 88 102" stroke="#b999bd" stroke-width="5"/>
    <circle cx="88" cy="87" r="3" fill="#ffffff" stroke="none"/>`,

  balloon: `
    <ellipse cx="60" cy="46" rx="29" ry="35" fill="#ef9a84"/>
    <path d="M57 80 54 88H66L63 80Z" fill="#e97870" stroke-width="2.5"/>
    <path d="M60 88Q70 96 60 102Q50 110 62 113" stroke="#a77c59" stroke-width="2.5"/>
    <path d="M40 40Q40 26 50 22" stroke="#ffd0b7" stroke-width="6"/>
    <path d="M42 50V53" stroke="#ffd0b7" stroke-width="4"/>`,

  skateboard: `
    <ellipse cx="59" cy="104" rx="43" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M35 76 31 92 M86 62 83 80" stroke="#8b8e9d" stroke-width="5"/>
    <circle cx="30" cy="94" r="9" fill="#efc979"/><circle cx="82" cy="82" r="9" fill="#efc979"/>
    <circle cx="42" cy="92" r="7" fill="#d5a862"/><circle cx="94" cy="79" r="7" fill="#d5a862"/>
    <path d="M13 72Q13 62 24 59L88 42Q102 37 108 45Q113 54 99 59L35 80Q18 85 13 72Z" fill="#b999bd"/>
    <path d="M13 72Q19 79 33 74L100 53Q108 50 108 45V53Q106 58 98 62L35 83Q18 88 13 77Z" fill="#927d99" stroke-width="2.5"/>
    <path d="M37 58 46 70 M75 48 84 59" stroke="#dfc6df" stroke-width="7"/>
    <circle cx="27" cy="66" r="1.8" fill="#765445" stroke="none"/><circle cx="31" cy="72" r="1.8" fill="#765445" stroke="none"/>
    <circle cx="93" cy="48" r="1.8" fill="#765445" stroke="none"/><circle cx="96" cy="54" r="1.8" fill="#765445" stroke="none"/>`,

  window: `
    <rect x="26" y="20" width="68" height="80" rx="3" fill="#d99d69"/>
    <rect x="33" y="27" width="54" height="66" fill="#d3edf0" stroke-width="2.5"/>
    <circle cx="74" cy="39" r="8" fill="#f8d86d" stroke="none"/>
    <path d="M33 81Q50 67 64 80Q75 72 87 80V93H33Z" fill="#acd18e" stroke="none"/>
    <path d="M60 27V93 M33 60H87" stroke="#f3d4af" stroke-width="6"/>
    <path d="M19 18H101 M19 102H101" stroke="#a77c59" stroke-width="6"/>
    <path d="M22 22H40Q40 51 25 64L34 94H16Z M80 22H98L104 94H86L95 64Q80 51 80 22Z" fill="#b999bd" stroke-width="2.5"/>
    <path d="M19 64H28 M92 64H101" stroke="#efc979" stroke-width="4"/>`,

  mirror: `
    <ellipse cx="60" cy="108" rx="31" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M60 80V100 M42 103Q60 96 78 103V107H42Z" fill="#d5a862" stroke-width="4"/>
    <ellipse cx="60" cy="48" rx="32" ry="38" fill="#edc779"/>
    <ellipse cx="60" cy="48" rx="25" ry="31" fill="#c5d6db" stroke="#a77c59" stroke-width="2.5"/>
    <path d="M45 42 60 27 M43 60 70 33 M59 69 75 53" stroke="#eef9fb" stroke-width="5"/>
    <path d="M35 40Q36 23 48 17" stroke="#fff0b3" stroke-width="3"/>`,

  pillow: `
    <ellipse cx="60" cy="103" rx="42" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M18 31Q40 39 60 32Q81 38 102 30Q95 55 103 91Q80 85 60 93Q40 86 17 93Q25 64 18 31Z" fill="#d3edf0"/>
    <path d="M26 40Q42 45 60 40Q80 44 94 39Q88 61 95 83Q78 78 60 85Q42 79 26 84Q32 62 26 40Z" stroke="#9ec9e0" stroke-width="2"/>
    <path d="M18 31 32 47 M102 30 87 47 M17 93 33 78 M103 91 88 77" stroke="#83adbe" stroke-width="2.5"/>
    <path d="M39 48Q50 44 60 46" stroke="#ffffff" stroke-width="4"/>`,

  blanket: `
    <path d="M23 32H95L103 92Q65 103 19 92L25 43Z" fill="#db9dac"/>
    <path d="M23 32Q26 24 35 24H90Q99 26 95 37L94 45H31Q20 43 23 32Z" fill="#f0d4d9"/>
    <path d="M33 31H90" stroke="#db9dac" stroke-width="3"/>
    <path d="M38 45 35 94 M59 45V97 M80 45 85 95 M24 60H98 M22 80H101" stroke="#f3d4af" stroke-width="6"/>
    <path d="M44 45 42 94 M65 45 66 97 M86 45 91 94 M24 66H99 M21 86H102" stroke="#b0788f" stroke-width="2"/>
    <path d="M22 96 21 103 M32 98 31 106 M43 99 43 107 M54 100V108 M65 100V108 M76 99 77 107 M87 98 89 105 M98 96 100 103" stroke="#db9dac" stroke-width="3"/>`,

  sofa: `
    <ellipse cx="60" cy="108" rx="43" ry="3" fill="#eadbc5" stroke="none"/>
    <path d="M28 94V105 M92 94V105" stroke="#a77c59" stroke-width="7"/>
    <rect x="24" y="31" width="72" height="58" rx="13" fill="#b999bd"/>
    <path d="M60 38V72" stroke="#927d99" stroke-width="2.5"/>
    <rect x="21" y="68" width="78" height="30" rx="7" fill="#b999bd"/>
    <rect x="29" y="66" width="31" height="18" rx="6" fill="#dfc6df" stroke-width="2.5"/>
    <rect x="60" y="66" width="31" height="18" rx="6" fill="#dfc6df" stroke-width="2.5"/>
    <path d="M12 68Q12 57 23 57Q34 57 34 68V93H21Q12 93 12 84Z M86 68Q86 57 97 57Q108 57 108 68V84Q108 93 99 93H86Z" fill="#c7b2d9"/>
    <path d="M35 40H49 M71 40H85" stroke="#ecd8e8" stroke-width="4"/>`,

  finger: `
    <path d="M39 105 35 93Q25 86 25 74V62Q25 56 31 56Q37 56 37 63V69L39 54V21Q39 14 46 14Q53 14 53 21V56Q57 49 64 54Q70 50 75 57Q84 54 85 63V82Q85 94 76 100V105Z" fill="#efbd9d"/>
    <path d="M42 22Q46 19 50 22V30H42Z" fill="#f8d7bd" stroke="#d99a82" stroke-width="1.5"/>
    <path d="M53 58V75Q58 82 63 75V57 M64 62V77Q69 83 74 77V61 M75 66V78Q79 83 84 77 M38 71Q47 74 49 85 M43 94H70" stroke="#c98d78" stroke-width="2"/>
    <path d="M38 101H77V111H38Z" fill="#9ec9e0" stroke-width="2.5"/>
    ${focus(46, 33, 19)}`,

  thumb: `
    <path d="M30 98V67Q31 59 42 50L46 23Q47 14 55 17Q65 22 63 34L60 53H83Q95 53 94 63L88 91Q86 101 75 101Z" fill="#efbd9d"/>
    <path d="M50 22Q54 20 59 25L58 34H49Z" fill="#f8d7bd" stroke="#d99a82" stroke-width="1.5"/>
    <path d="M60 54Q51 62 61 69H91 M62 70Q55 77 64 81H88 M64 82Q58 89 68 93H86 M40 70Q45 79 44 88" stroke="#c98d78" stroke-width="2.5"/>
    <rect x="19" y="64" width="15" height="39" rx="3" fill="#9ec9e0" stroke-width="2.5"/>
    ${focus(54, 34, 20)}`,

  elbow: `
    <path d="M16 27 35 20 50 51 38 61Z" fill="#9ec9e0"/>
    <path d="M39 52 48 47 60 72 76 52 81 37Q81 31 86 33L88 43 92 29Q95 25 99 29L96 46 103 41Q109 41 105 48L92 62 70 90Q58 103 49 89Z" fill="#efbd9d"/>
    <path d="M52 80Q57 87 63 81 M74 64 68 73 M88 49 94 51" stroke="#c98d78" stroke-width="2.5"/>
    ${focus(58, 83, 15)}`,

  knee: `
    <path d="M14 22H42L45 47 27 60 14 42Z" fill="#9ec9e0"/>
    <path d="M30 52 43 43 76 53Q85 57 80 71L70 93 89 98Q98 100 94 106H64Q55 105 57 97L65 72Z" fill="#efbd9d"/>
    <path d="M66 59Q74 58 76 64 M69 77 64 91 M69 96 73 99 M86 100V105" stroke="#c98d78" stroke-width="2.5"/>
    ${focus(71, 63, 14)}`,

  ankle: `
    <path d="M36 13H73L68 35H38Z" fill="#9ec9e0"/>
    <path d="M40 34H67L62 75Q61 83 70 88L94 97Q101 101 96 107H58Q39 106 41 92L44 73Z" fill="#efbd9d"/>
    <path d="M49 43 51 65 M51 84Q58 79 61 86 M59 94Q57 101 64 101 M87 99V105 M92 100V106" stroke="#c98d78" stroke-width="2.5"/>
    ${focus(56, 84, 13)}`,

  dolphin: `
    <path d="M53 39Q58 23 72 21Q66 33 72 45" fill="#85bfda"/>
    <path d="M21 54Q27 37 42 36Q73 29 86 63L97 69Q98 58 109 55L105 74 112 87Q99 90 92 79L80 74Q61 78 43 64L18 66Q9 64 13 59Z" fill="#85bfda"/>
    <path d="M20 63Q45 62 59 70Q69 74 80 74" stroke="#d1eaf1" stroke-width="5"/>
    <path d="M50 61Q66 68 64 88Q51 83 48 69Z" fill="#69aacb" stroke-width="2.5"/>
    <circle cx="32" cy="51" r="3" fill="#765445" stroke="none"/>
    <path d="M18 61Q26 67 34 61 M24 97Q39 93 53 98 M75 101H96" stroke-width="2.5"/>`,

  octopus: `
    <path d="${octopusArms}" stroke="#765445" stroke-width="12"/>
    <path d="${octopusArms}" stroke="#d8b9dc" stroke-width="7"/>
    <path d="M34 52Q31 22 60 20Q89 22 86 52L80 73Q60 87 40 73Z" fill="#d8b9dc"/>
    <circle cx="48" cy="51" r="3.5" fill="#765445" stroke="none"/><circle cx="72" cy="51" r="3.5" fill="#765445" stroke="none"/>
    <path d="M54 63Q60 70 66 63" stroke-width="2.5"/>
    <path d="M43 38Q47 28 57 28" stroke="#f1d9ed" stroke-width="4"/>
    <g fill="#f1d9ed" stroke="none">
      <circle cx="25" cy="64" r="2"/><circle cx="24" cy="82" r="2"/><circle cx="32" cy="94" r="2"/><circle cx="47" cy="99" r="2"/>
      <circle cx="73" cy="99" r="2"/><circle cx="88" cy="94" r="2"/><circle cx="96" cy="82" r="2"/><circle cx="95" cy="64" r="2"/>
    </g>`,

  jellyfish: `
    <path d="M35 61Q28 77 39 88Q48 98 34 109 M49 62Q40 83 52 104 M60 62Q69 80 60 94Q56 102 62 110 M72 62Q83 82 71 104 M85 61Q93 78 81 88Q73 99 88 108" stroke="#b78dbd" stroke-width="4"/>
    <path d="M22 57Q22 17 60 16Q98 17 98 57Q92 67 84 59Q76 70 68 61Q60 72 52 61Q44 70 36 59Q28 67 22 57Z" fill="#d8b9dc"/>
    <path d="M33 40Q39 26 52 25" stroke="#f1d9ed" stroke-width="5"/>
    <path d="M42 55Q44 32 59 21 M78 55Q76 32 61 21" stroke="#b78dbd" stroke-width="2"/>
    <circle cx="48" cy="47" r="2.5" fill="#765445" stroke="none"/><circle cx="72" cy="47" r="2.5" fill="#765445" stroke="none"/>
    <path d="M56 54Q60 58 64 54" stroke-width="2"/>`,

  seahorse: `
    <path d="M50 53 31 50 36 64 31 75 50 70Z" fill="#efb660" stroke-width="2.5"/>
    <path d="M52 43 45 31 53 20 51 12 62 17Q76 14 82 29L100 34 97 44 78 41Q62 45 68 58Q85 77 68 89Q56 95 57 102Q62 111 71 103Q76 96 68 96Q62 98 66 101Q59 98 63 91Q76 86 82 98Q85 113 66 115Q42 114 43 99Q43 91 52 86Q61 81 50 72Q39 60 52 43Z" fill="#efc979"/>
    <path d="M60 51 66 52 M57 60H70 M57 70H74 M60 80H70 M36 56 47 62 M37 69 47 66" stroke="#d5a862" stroke-width="2.5"/>
    <circle cx="70" cy="29" r="3" fill="#765445" stroke="none"/>
    <path d="M96 37 97 38" stroke-width="2"/>`,

  starfish: `
    <path d="M60 14Q65 11 68 20L76 43 102 43Q111 43 105 51L85 69 94 96Q96 106 86 101L60 85 34 101Q24 106 26 96L35 69 15 51Q9 43 18 43H44L52 20Q55 11 60 14Z" fill="#efb660"/>
    <path d="M60 32V60 M29 51 60 60 91 51 M60 60 40 89 M60 60 80 89" stroke="#d5a862" stroke-width="2"/>
    <g fill="#fff0b3" stroke="none">
      <circle cx="60" cy="26" r="2.5"/><circle cx="60" cy="39" r="2.5"/><circle cx="60" cy="51" r="2.5"/>
      <circle cx="32" cy="51" r="2.5"/><circle cx="45" cy="55" r="2.5"/><circle cx="76" cy="55" r="2.5"/><circle cx="89" cy="51" r="2.5"/>
      <circle cx="40" cy="88" r="2.5"/><circle cx="48" cy="76" r="2.5"/><circle cx="72" cy="76" r="2.5"/><circle cx="80" cy="88" r="2.5"/>
    </g>
    <circle cx="60" cy="64" r="7" fill="#f4d36a" stroke-width="2"/>`,

  astronaut: `
    <rect x="30" y="46" width="60" height="35" rx="8" fill="#b3c5cc" stroke-width="2.5"/>
    <path d="M40 59 23 82 14 75 27 55Q32 49 40 53 M80 59 97 82 106 75 93 55Q88 49 80 53" fill="#fff7e6"/>
    <path d="M40 52H80L83 86 78 105H64V89H56V105H42L37 86Z" fill="#fff7e6"/>
    <path d="M39 98H56V109H36V103Z M64 98H81L84 103V109H64Z" fill="#b3c5cc" stroke-width="2.5"/>
    <path d="M19 69 28 75 M92 75 101 69 M39 83H81" stroke="#ef9a84" stroke-width="4"/>
    <circle cx="60" cy="34" r="26" fill="#fff7e6"/>
    <rect x="40" y="18" width="40" height="31" rx="14" fill="#6c9ab7" stroke-width="2.5"/>
    <path d="M47 29Q49 23 58 23" stroke="#d3edf0" stroke-width="4"/>
    <rect x="48" y="63" width="24" height="15" rx="3" fill="#9ec9e0" stroke-width="2"/>
    <circle cx="54" cy="70" r="2" fill="#e97870" stroke="none"/><path d="M61 69H67 M61 73H67" stroke="#fff7e6" stroke-width="2"/>`,

  satellite: `
    <path d="M30 64H90" stroke="#a2b9c3" stroke-width="6"/>
    <path d="M10 46 37 40 41 79 14 85Z M79 40 106 46 110 85 83 79Z" fill="#85bfda"/>
    <path d="M18 44 22 83 M27 42 31 81 M12 59 38 53 M13 72 40 66 M88 42 92 81 M97 44 101 83 M80 53 108 59 M82 66 109 72" stroke="#d3edf0" stroke-width="2"/>
    <path d="M47 44 60 38 73 44 73 82 60 89 47 82Z" fill="#edc779"/>
    <path d="M47 44 60 50 73 44 M60 50V89" stroke="#a77c59" stroke-width="2"/>
    <path d="M60 39V27" stroke="#8b8e9d" stroke-width="3"/>
    <path d="M43 15Q60 42 79 19Z" fill="#d3edf0" stroke-width="2.5"/>
    <path d="M60 26 62 11" stroke-width="2.5"/>
    <circle cx="62" cy="10" r="3" fill="#ef9a84" stroke="none"/>
    <path d="M29 99V107 M25 103H33 M92 20V28 M88 24H96" stroke="#d5b873" stroke-width="2.5"/>`,

  telescope: `
    <path d="M60 71 35 108 M60 71 85 108 M60 71V108" stroke="#8b8e9d" stroke-width="4"/>
    <circle cx="60" cy="70" r="6" fill="#edc779" stroke-width="2.5"/>
    <path d="M28 61 80 26 93 47 41 82Z" fill="#9ec9e0"/>
    <path d="M74 30 83 24 97 45 88 51Z" fill="#b3c5cc" stroke-width="2.5"/>
    <ellipse cx="90" cy="34" rx="7" ry="14" transform="rotate(-34 90 34)" fill="#6c9ab7" stroke-width="2.5"/>
    <path d="M87 27 92 32" stroke="#d3edf0" stroke-width="3"/>
    <path d="M20 69 30 62 39 77 29 84Z" fill="#b3c5cc" stroke-width="2.5"/>
    <path d="M17 73 25 86" stroke="#6d7988" stroke-width="5"/>
    <path d="M42 58 66 42" stroke="#d3edf0" stroke-width="4"/>
    <path d="M24 23V33 M19 28H29" stroke="#d5b873" stroke-width="2.5"/>`,

  spaceship: `
    <path d="M38 82 31 98 M82 82 89 98" stroke="#8b8e9d" stroke-width="4"/>
    <path d="M24 100H37 M83 100H96" stroke="#8b8e9d" stroke-width="5"/>
    <path d="M33 60Q30 24 60 23Q90 24 87 60Z" fill="#a9d9df"/>
    <path d="M43 43Q46 31 58 31" stroke="#eef9fb" stroke-width="5"/>
    <ellipse cx="60" cy="68" rx="45" ry="18" fill="#b999bd"/>
    <path d="M15 68Q60 90 105 68" stroke="#927d99" stroke-width="3"/>
    <ellipse cx="60" cy="61" rx="45" ry="12" fill="#c7b2d9"/>
    <circle cx="31" cy="62" r="4" fill="#f8d86d" stroke-width="2"/><circle cx="60" cy="66" r="4" fill="#f8d86d" stroke-width="2"/><circle cx="89" cy="62" r="4" fill="#f8d86d" stroke-width="2"/>
    <path d="M17 30V38 M13 34H21 M102 22V32 M97 27H107" stroke="#d5b873" stroke-width="2.5"/>`,

  asteroid: `
    <path d="M29 34 52 21 77 29 96 51 91 78 70 102 43 96 20 76 18 53Z" fill="#b58b69"/>
    <path d="M79 34 89 55 81 80 62 96 70 102 91 78 96 51Z" fill="#93785d" stroke="none"/>
    <ellipse cx="40" cy="49" rx="13" ry="10" transform="rotate(-27 40 49)" fill="#a77c59" stroke-width="2.5"/>
    <path d="M29 49Q35 37 47 44" stroke="#e9c291" stroke-width="3"/>
    <ellipse cx="70" cy="65" rx="12" ry="15" transform="rotate(25 70 65)" fill="#a77c59" stroke-width="2.5"/>
    <path d="M65 54Q74 48 80 59" stroke="#e9c291" stroke-width="3"/>
    <circle cx="45" cy="80" r="6" fill="#a77c59" stroke-width="2.5"/>
    <path d="M63 35 66 37 M30 67 33 68 M56 93 59 94" stroke="#e9c291" stroke-width="3"/>
    <path d="M94 13 102 9 110 16 107 25 97 23Z M10 94 17 90 23 98 18 106 9 103Z" fill="#c8a078" stroke-width="2.5"/>`,

  mushroom: `
    <ellipse cx="60" cy="108" rx="34" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M49 50H71L74 88Q80 106 60 107Q40 106 46 88Z" fill="#fff1d9"/>
    <path d="M54 73 51 94" stroke="#e7d8b8" stroke-width="3"/>
    <path d="M13 60Q25 15 60 15Q95 15 107 60Q108 69 90 72H30Q12 69 13 60Z" fill="#ef9a84"/>
    <ellipse cx="60" cy="66" rx="43" ry="9" fill="#f3d4af" stroke-width="2.5"/>
    <path d="M31 65 47 68 M44 61 53 67 M60 59V67 M76 61 67 67 M89 65 73 68" stroke="#c8a078" stroke-width="1.8"/>
    <ellipse cx="37" cy="42" rx="10" ry="8" transform="rotate(-30 37 42)" fill="#fff1d9" stroke="none"/>
    <circle cx="61" cy="28" r="8" fill="#fff1d9" stroke="none"/>
    <ellipse cx="84" cy="43" rx="10" ry="8" transform="rotate(30 84 43)" fill="#fff1d9" stroke="none"/>
    <circle cx="61" cy="50" r="5" fill="#fff1d9" stroke="none"/>`,

  cactus: `
    <ellipse cx="60" cy="108" rx="35" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M49 87V64H36Q20 64 20 47V36Q20 29 28 29Q36 29 36 36V48H49V26Q49 15 60 15Q71 15 71 26V59H84V43Q84 36 92 36Q100 36 100 43V58Q100 75 83 75H71V87Z" fill="#91bd7e"/>
    <path d="M60 26V84 M28 37V47Q28 56 40 56 M92 44V58Q92 67 80 67" stroke="#699a65" stroke-width="2.5"/>
    <path d="M54 36 49 33 M67 48 72 45 M54 65 49 68 M36 50 40 46 M88 52 84 50" stroke="#765445" stroke-width="1.5"/>
    <path d="M36 87H84L78 106H42Z" fill="#d99d69"/>
    <rect x="33" y="83" width="54" height="9" rx="3" fill="#e7bb94" stroke-width="2.5"/>`,

  bamboo: `
    <path d="M31 107 35 19H47L43 107Z M55 107 56 11H69L68 107Z M80 107 76 31H88L94 107Z" fill="#91bd7e"/>
    <path d="M35 36H46 M33 61H45 M32 86H44 M56 31H69 M55 58H69 M55 85H69 M77 54H90 M79 80H92" stroke="#699a65" stroke-width="3"/>
    <path d="M37 62 22 40 M64 51 93 23 M86 80 103 60" stroke="#699a65" stroke-width="2.5"/>
    <path d="M28 48Q11 49 10 32Q23 32 28 48Z M31 52Q25 31 34 24Q43 38 31 52Z M79 37Q73 18 84 11Q89 25 79 37Z M81 37Q94 21 107 26Q100 40 81 37Z M97 69Q91 53 102 45Q108 57 97 69Z M97 72Q104 59 113 63Q111 76 97 72Z" fill="#78ad72" stroke-width="2"/>
    <path d="M40 23V30 M62 16V24 M82 35 83 47 M20 108H101" stroke="#dceba1" stroke-width="3"/>`,

  pinecone: `
    <ellipse cx="60" cy="109" rx="31" ry="3" fill="#eadbc5" stroke="none"/>
    <path d="M60 103 61 113" stroke="#a77c59" stroke-width="4"/>
    <path d="M60 14Q84 25 88 53Q100 80 80 98Q60 115 40 98Q20 80 32 53Q36 25 60 14Z" fill="#b58b69"/>
    <path d="M49 24Q60 42 71 24 M41 37Q49 54 60 38Q71 54 79 37 M34 52Q43 69 51 52Q60 69 69 52Q77 69 86 52 M31 68Q40 85 49 68Q60 85 71 68Q80 85 89 68 M36 84Q47 100 60 84Q73 100 84 84 M48 99Q60 110 72 99" stroke="#765445" stroke-width="2.5"/>
    <path d="M54 25 60 30 M45 41 49 46 M37 55 42 61 M34 72 39 78 M42 88 47 92" stroke="#e9c291" stroke-width="3"/>`,

  sunflower: `
    <path d="M60 65V109" stroke="#699a65" stroke-width="5"/>
    <path d="M59 96Q35 99 26 80Q51 76 59 96Z M61 87Q69 68 94 73Q86 94 61 87Z" fill="#91bd7e" stroke="#699a65" stroke-width="2.5"/>
    ${Array.from({ length: 12 }, (_, index) => `<ellipse cx="60" cy="22" rx="7" ry="15" transform="rotate(${index * 30} 60 47)" fill="#f4d36a" stroke-width="2.5"/>`).join('\n    ')}
    <circle cx="60" cy="47" r="21" fill="#a77c59"/>
    <circle cx="60" cy="47" r="16" fill="#b58b69" stroke="#d5a862" stroke-width="2"/>
    <g fill="#f3d4af" stroke="none">
      <circle cx="54" cy="38" r="2"/><circle cx="65" cy="38" r="2"/><circle cx="49" cy="47" r="2"/><circle cx="60" cy="47" r="2"/><circle cx="71" cy="47" r="2"/><circle cx="54" cy="56" r="2"/><circle cx="65" cy="56" r="2"/>
    </g>`,

  trumpet: `
    <path d="M18 52H73" stroke="#d5a862" stroke-width="10"/>
    <path d="M32 54V75Q32 86 44 86H66Q76 86 76 75V60" stroke="#d5a862" stroke-width="8"/>
    <path d="M32 54V75Q32 86 44 86H66Q76 86 76 75V60" stroke="#f3d899" stroke-width="3"/>
    <path d="M71 47Q88 40 100 31V81Q88 68 71 63Z" fill="#edc779"/>
    <ellipse cx="100" cy="56" rx="8" ry="25" fill="#d5a862" stroke-width="2.5"/>
    <ellipse cx="101" cy="56" rx="4" ry="18" fill="#a77c59" stroke="none"/>
    <path d="M41 42V74 M52 42V74 M63 42V74" stroke="#edc779" stroke-width="5"/>
    <path d="M37 41H45 M48 41H56 M59 41H67 M12 46V58" stroke="#a77c59" stroke-width="3"/>
    <path d="M11 51H20" stroke="#d5a862" stroke-width="5"/>
    <path d="M18 22V32 M13 27H23" stroke="#b999bd" stroke-width="2.5"/>`,

  saxophone: `
    <path d="M41 22Q60 12 65 31L49 81Q47 91 60 94Q73 96 76 81L80 62" stroke="#a77c59" stroke-width="16"/>
    <path d="M41 22Q60 12 65 31L49 81Q47 91 60 94Q73 96 76 81L80 62" stroke="#edc779" stroke-width="11"/>
    <path d="M70 71Q75 57 71 40L103 50Q90 60 87 75Z" fill="#edc779"/>
    <ellipse cx="87" cy="45" rx="17" ry="8" transform="rotate(17 87 45)" fill="#d5a862" stroke-width="2.5"/>
    <ellipse cx="87" cy="45" rx="11" ry="4" transform="rotate(17 87 45)" fill="#a77c59" stroke="none"/>
    <path d="M29 20 44 16 46 24 31 28Z" fill="#6d6866" stroke-width="2.5"/>
    <path d="M55 40 45 74" stroke="#a77c59" stroke-width="2"/>
    <circle cx="54" cy="42" r="4" fill="#f3d899" stroke-width="2"/><circle cx="50" cy="54" r="4" fill="#f3d899" stroke-width="2"/><circle cx="46" cy="66" r="4" fill="#f3d899" stroke-width="2"/>
    <path d="M53 87Q56 91 62 91" stroke="#fff0b3" stroke-width="3"/>`,

  xylophone: `
    <path d="M16 42H106 M16 97 106 79" stroke="#a77c59" stroke-width="6"/>
    ${['#e97870', '#ee9c54', '#f4d36a', '#91bd7e', '#85bfda', '#b999bd'].map((color, index) => {
      const x = 18 + index * 14;
      const y = 31 + index * 3;
      const height = 70 - index * 6;
      return `<rect x="${x}" y="${y}" width="12" height="${height}" rx="3" fill="${color}" stroke-width="2.5"/>
    <circle cx="${x + 6}" cy="${y + 7}" r="1.5" fill="#765445" stroke="none"/><circle cx="${x + 6}" cy="${y + height - 7}" r="1.5" fill="#765445" stroke="none"/>`;
    }).join('\n    ')}
    <path d="M35 22 78 40 M83 19 43 43" stroke="#b58b69" stroke-width="4"/>
    <circle cx="32" cy="20" r="7" fill="#f3d4af" stroke-width="2.5"/><circle cx="86" cy="17" r="7" fill="#f3d4af" stroke-width="2.5"/>`,

  cymbal: `
    <path d="M60 52V91 M60 86 34 108 M60 86 86 108 M60 86V110" stroke="#8b8e9d" stroke-width="4"/>
    <ellipse cx="60" cy="54" rx="46" ry="13" fill="#d5a862"/>
    <path d="M14 51Q30 44 45 42Q60 27 75 42Q90 44 106 51Q60 70 14 51Z" fill="#edc779"/>
    <path d="M26 53Q60 64 94 53 M33 48 46 45 M75 45 87 48" stroke="#fff0b3" stroke-width="2.5"/>
    <path d="M60 31V42" stroke="#8b8e9d" stroke-width="3"/>
    <ellipse cx="60" cy="38" rx="6" ry="3" fill="#a77c59" stroke-width="2"/>
    <path d="M21 28 27 33 M14 36 22 38 M94 29 100 24 M99 38 108 36" stroke="#b999bd" stroke-width="2.5"/>`,

  microphone: `
    <path d="M32 94Q17 102 31 109Q41 115 51 109" stroke="#8b8e9d" stroke-width="3"/>
    <path d="M31 96 22 89 52 47 70 59Z" fill="#927d99"/>
    <path d="M27 81 39 90 M51 53 66 63" stroke="#c7b2d9" stroke-width="4"/>
    <circle cx="74" cy="35" r="25" fill="#b3c5cc"/>
    <path d="M61 16 96 41 M53 26 89 52 M52 40 75 57 M75 15 54 44 M87 21 65 54 M95 31 79 54" stroke="#8fa8b3" stroke-width="2"/>
    <path d="M63 20Q70 15 77 17" stroke="#eef9fb" stroke-width="4"/>
    <path d="M40 70 45 63" stroke="#fff7e6" stroke-width="3"/>`
};
