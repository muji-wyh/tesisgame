// Original noun illustrations, drawn for the shared 120-by-120 word-art canvas.
function spotlight(x, y, radius, arrowX) {
  return `<circle cx="${x}" cy="${y}" r="${radius}" fill="none" stroke="#e9ad45" stroke-width="3"/>
    <path d="M${arrowX} ${y}H${x + radius + 5} m6 -5 -6 5 6 5" fill="none" stroke="#dca83d" stroke-width="3"/>`;
}

module.exports = {
  bird: `
    <path d="M17 103H103" stroke="#b58b69" stroke-width="5"/>
    <path d="M54 86 50 102 M69 86 72 102 M46 103H56 M68 103H78" stroke-width="2.5"/>
    <path d="M31 62 14 46 16 78 37 81 Q53 97 76 86 Q95 75 87 53 Q98 36 86 25 Q71 14 59 29 Q53 39 57 49 Q39 47 31 62Z" fill="#9ec9e0"/>
    <path d="M85 36 103 43 87 49Z" fill="#efbc72" stroke-width="2.5"/>
    <path d="M38 60 Q64 46 74 64 Q65 85 43 76Z" fill="#81b4ce" stroke-width="2.5"/>
    <path d="M46 65 62 61 M48 72 60 70" stroke="#cfeaf0" stroke-width="2.5"/>
    <circle cx="77" cy="34" r="3" fill="#765445" stroke="none"/>
    <circle cx="81" cy="47" r="4" fill="#f4c2b3" stroke="none"/>`,

  bat: `
    <path d="M52 55 Q32 29 12 35 L19 72 Q26 61 35 76 Q44 66 54 85 M68 55 Q88 29 108 35 L101 72 Q94 61 85 76 Q76 66 66 85" fill="#b0a0ce"/>
    <path d="M52 60 18 39 M51 64 35 73 M68 60 102 39 M69 64 85 73" stroke="#8e7aa8" stroke-width="2.5"/>
    <path d="M46 45 45 21 57 32 H64 L76 21 74 45 Q84 68 68 91 L60 99 52 91 Q37 68 46 45Z" fill="#91849e"/>
    <path d="M49 28 51 41 M72 28 68 41" stroke="#d4b4c7" stroke-width="3"/>
    <ellipse cx="60" cy="69" rx="10" ry="16" fill="#b6a8c4" stroke="none"/>
    <circle cx="53" cy="47" r="3" fill="#765445" stroke="none"/><circle cx="67" cy="47" r="3" fill="#765445" stroke="none"/>
    <path d="M54 57 Q60 62 66 57 M55 92 54 100 M65 92 66 100" stroke-width="2.5"/>`,

  deer: `
    <ellipse cx="59" cy="107" rx="41" ry="3" fill="#eadbc5" stroke="none"/>
    <path d="M74 66 101 56 96 69 83 76" fill="#d5a378"/>
    <path d="M35 56 Q52 51 72 60 Q87 61 88 78 L83 103 H76 L75 84 H56 L53 103 H46 L45 81 H36 L33 103 H26 L28 70Z" fill="#d5a378"/>
    <path d="M41 65 47 78 M65 67 70 78" stroke="#f5d9b2" stroke-width="4"/>
    <path d="M33 64 26 45 Q21 37 27 29 Q34 22 46 28 L53 39 48 61Z" fill="#deb58c"/>
    <path d="M28 30 14 27 Q10 35 26 40 M46 30 60 26 Q64 33 49 40" fill="#d5a378" stroke-width="2.5"/>
    <path d="M32 26 29 13 M29 19 21 13 M42 25 45 12 M45 19 53 12" stroke="#aa805e" stroke-width="3"/>
    <circle cx="32" cy="41" r="2.8" fill="#765445" stroke="none"/><circle cx="44" cy="41" r="2.8" fill="#765445" stroke="none"/>
    <ellipse cx="38" cy="51" rx="9" ry="7" fill="#f4d8b8" stroke="none"/>
    <path d="M35 48H41L38 52Z" fill="#765445" stroke="none"/>
    <path d="M26 100H33 M46 100H53 M76 100H83" stroke="#93785d" stroke-width="3"/>`,

  snake: `
    <ellipse cx="57" cy="104" rx="41" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M19 89 Q40 104 76 90 Q86 85 78 79 Q72 73 52 77 Q19 83 20 64 Q21 48 54 47 L72 46 Q83 43 80 34" stroke="#765445" stroke-width="18"/>
    <path d="M19 89 Q40 104 76 90 Q86 85 78 79 Q72 73 52 77 Q19 83 20 64 Q21 48 54 47 L72 46 Q83 43 80 34" stroke="#91bd7e" stroke-width="11"/>
    <path d="M76 42 Q61 38 65 26 Q70 16 88 22 Q101 27 97 37 Q92 45 76 42Z" fill="#a8cb88"/>
    <circle cx="88" cy="28" r="3" fill="#765445" stroke="none"/>
    <path d="M96 35 107 36 M104 36 108 32 M104 36 108 40" stroke="#df8683" stroke-width="2"/>
    <path d="M37 52 39 60 M54 45 56 53 M27 68 34 67 M49 74 51 81 M73 82 70 90 M44 94 44 101" stroke="#6b9c67" stroke-width="3"/>`,

  snail: `
    <ellipse cx="60" cy="104" rx="46" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M15 94 Q28 81 63 86 L79 77 83 62 Q86 54 93 60 L98 77 Q104 88 96 97 Q75 107 15 100Z" fill="#b6cf8d"/>
    <path d="M87 63 81 44 M94 64 102 43" stroke="#92b17a" stroke-width="4"/>
    <circle cx="80" cy="42" r="5" fill="#b6cf8d" stroke-width="2.5"/><circle cx="103" cy="41" r="5" fill="#b6cf8d" stroke-width="2.5"/>
    <circle cx="81" cy="42" r="2" fill="#765445" stroke="none"/><circle cx="104" cy="41" r="2" fill="#765445" stroke="none"/>
    <path d="M86 81 Q90 86 95 81" stroke-width="2"/>
    <circle cx="48" cy="64" r="30" fill="#efc28b"/>
    <path d="M68 80 Q39 96 29 71 Q23 48 45 43 Q65 39 68 58 Q71 73 56 77 Q43 80 39 67 Q35 56 47 53 Q58 50 59 61 Q61 69 51 67" stroke="#b88b63" stroke-width="3"/>`,

  worm: `
    <path d="M18 99 Q39 87 63 94 Q88 88 105 100" stroke="#b7c98c" stroke-width="5"/>
    <path d="M22 85 C31 103 43 103 53 81 S70 69 79 79 S99 76 98 53 L94 34" stroke="#765445" stroke-width="19"/>
    <path d="M22 85 C31 103 43 103 53 81 S70 69 79 79 S99 76 98 53 L94 34" stroke="#eeb3a5" stroke-width="12"/>
    <path d="M27 90 19 94 M36 91 34 104 M46 85 54 94 M54 73 65 80 M70 68 67 82 M82 74 80 87 M90 67 102 69 M91 54 104 54 M88 43 101 42" stroke="#c88d86" stroke-width="2"/>
    <ellipse cx="92" cy="30" rx="12" ry="14" fill="#f1bcae"/>
    <circle cx="88" cy="27" r="2.5" fill="#765445" stroke="none"/><circle cx="97" cy="27" r="2.5" fill="#765445" stroke="none"/>
    <path d="M89 35 Q93 39 97 34" stroke-width="2"/>`,

  spider: `
    <path d="M60 12V34" stroke="#c7bcac" stroke-width="2"/>
    <path d="M43 56 26 43 17 29 M42 65 22 60 12 48 M42 75 22 79 13 94 M48 83 34 94 32 108 M77 56 94 43 103 29 M78 65 98 60 108 48 M78 75 98 79 107 94 M72 83 86 94 88 108" stroke="#8f81a5" stroke-width="5"/>
    <ellipse cx="60" cy="72" rx="26" ry="27" fill="#b4a4cd"/>
    <path d="M45 72 Q60 82 75 72 M48 84 Q60 91 72 84" stroke="#d1c3e2" stroke-width="3"/>
    <circle cx="60" cy="48" r="19" fill="#c3b5d8"/>
    <circle cx="53" cy="45" r="4" fill="#fff5e5" stroke-width="2"/><circle cx="67" cy="45" r="4" fill="#fff5e5" stroke-width="2"/>
    <circle cx="54" cy="46" r="2" fill="#765445" stroke="none"/><circle cx="66" cy="46" r="2" fill="#765445" stroke="none"/>
    <path d="M54 56 Q60 61 66 56" stroke-width="2"/>`,

  chick: `
    <ellipse cx="60" cy="106" rx="31" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M46 91 45 104 M74 91 75 104 M37 105 45 102 52 105 M68 105 75 102 83 105" stroke="#d5a04e" stroke-width="3"/>
    <path d="M29 62 Q15 63 19 80 Q27 81 35 73 M91 62 Q105 63 101 80 Q93 81 85 73" fill="#f3ca65"/>
    <path d="M34 47 Q30 26 50 22 L51 13 59 21 67 12 70 23 Q89 28 86 47 Q100 62 90 83 Q82 97 60 97 Q38 97 30 83 Q20 62 34 47Z" fill="#f8d978"/>
    <path d="M50 62 60 56 70 62 60 69Z" fill="#efaa63" stroke-width="2.5"/>
    <circle cx="45" cy="49" r="3.5" fill="#765445" stroke="none"/><circle cx="75" cy="49" r="3.5" fill="#765445" stroke="none"/>
    <ellipse cx="40" cy="61" rx="5" ry="3" fill="#f1b995" stroke="none"/><ellipse cx="80" cy="61" rx="5" ry="3" fill="#f1b995" stroke="none"/>
    <path d="M46 81 Q60 87 74 81" stroke="#fff0af" stroke-width="5"/>`,

  lemon: `
    <ellipse cx="60" cy="105" rx="39" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M24 42 Q40 23 64 32 Q87 36 95 59 L104 67 95 77 Q80 99 54 92 Q30 89 24 65 L15 55Z" fill="#f7d968"/>
    <path d="M57 31 Q68 15 89 20 Q81 37 60 37Z" fill="#91bd7e"/>
    <path d="M35 48 Q45 38 56 40" stroke="#fff0ad" stroke-width="5"/>
    <path d="M35 67 37 70 M65 83 68 84 M84 63 85 66 M71 47 73 49 M52 61 54 62" stroke="#dcb64d" stroke-width="2.5"/>`,

  peach: `
    <ellipse cx="60" cy="106" rx="34" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M61 36 Q48 23 32 36 Q11 50 25 77 Q38 100 59 106 Q82 99 96 77 Q109 52 89 36 Q76 25 61 36Z" fill="#f0af92"/>
    <path d="M61 38 Q76 54 68 78 Q63 94 59 104" stroke="#d98e7e" stroke-width="3"/>
    <path d="M59 33 Q54 23 59 15" stroke="#93785d" stroke-width="4"/>
    <path d="M60 27 Q72 11 94 20 Q83 35 62 32Z" fill="#91bd7e"/>
    <path d="M38 44 Q27 53 31 64" stroke="#ffdac0" stroke-width="5"/>
    <ellipse cx="39" cy="78" rx="10" ry="7" fill="#ec9b8d" stroke="none"/>`,

  plum: `
    <ellipse cx="60" cy="106" rx="30" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M61 37 Q40 27 29 46 Q16 69 36 92 Q54 110 75 98 Q99 85 94 58 Q91 31 61 37Z" fill="#9d80b8"/>
    <path d="M64 39 Q76 67 68 99" stroke="#806897" stroke-width="2.5"/>
    <path d="M60 37 Q59 22 66 14" stroke="#93785d" stroke-width="4"/>
    <path d="M64 27 Q78 14 94 25 Q82 36 65 32Z" fill="#91bd7e"/>
    <path d="M41 45 Q29 56 32 70" stroke="#c8b2dc" stroke-width="5"/>
    <ellipse cx="47" cy="87" rx="8" ry="4" fill="#ac91c5" stroke="none"/>`,

  mango: `
    <ellipse cx="60" cy="106" rx="35" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M63 31 Q88 28 96 48 Q110 79 75 96 Q54 105 26 96 Q49 82 34 62 Q24 47 36 37 Q45 27 63 31Z" fill="#f0bd69"/>
    <path d="M39 41 Q34 54 45 66 Q53 80 37 94 Q64 97 82 83" fill="#ed9f6c" stroke="none"/>
    <path d="M64 31 Q67 23 62 15" stroke="#93785d" stroke-width="4"/>
    <path d="M63 24 Q81 11 102 26 Q83 34 65 29Z" fill="#8fbd79"/>
    <path d="M73 40 Q87 43 88 56" stroke="#ffe2a1" stroke-width="5"/>
    <path d="M53 95 Q69 96 82 86" stroke="#dba04e" stroke-width="2.5"/>`,

  nut: `
    <ellipse cx="60" cy="106" rx="38" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M43 23 Q64 13 75 31 Q80 42 75 50 Q70 58 81 65 Q103 79 90 96 Q76 111 56 95 Q45 86 39 84 Q17 77 23 59 Q27 47 36 43 Q42 39 37 34 Q34 27 43 23Z" fill="#dfbd87"/>
    <path d="M49 28 Q64 24 67 37 Q68 48 59 53 Q55 62 67 72 Q84 80 80 95" stroke="#a98057" stroke-width="2.5"/>
    <path d="M41 49 68 54 M32 59 62 66 M31 70 75 79 M45 28 68 36 M42 77 61 45 M51 84 74 65 M65 96 86 79" stroke="#c49a64" stroke-width="2"/>
    <path d="M47 30 48 41 M33 57 29 65" stroke="#f9dfb2" stroke-width="3"/>`,

  soup: `
    <ellipse cx="60" cy="106" rx="38" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M20 63 Q22 97 48 102 H74 Q99 97 101 63Z" fill="#9ec9e0"/>
    <ellipse cx="60" cy="61" rx="41" ry="14" fill="#fff0cd"/>
    <ellipse cx="60" cy="62" rx="34" ry="9" fill="#ebba72" stroke="none"/>
    <path d="M81 59 104 29" stroke="#765445" stroke-width="8"/><path d="M81 59 104 29" stroke="#b9cbd1" stroke-width="4"/>
    <path d="M38 31 Q29 23 38 15 M58 36 Q49 27 58 20 M76 31 Q67 23 76 15" stroke="#bfb8a7" stroke-width="2.5"/>
    <path d="M33 59 43 56 46 62 36 65Z M66 62 73 56 79 61 73 66Z" fill="#e79469" stroke="none"/>
    <path d="M52 57 57 62 M52 63 60 62 M85 65 89 61" stroke="#7caa70" stroke-width="3"/>
    <path d="M29 77 Q34 92 45 95" stroke="#dceff0" stroke-width="4"/>`,

  jam: `
    <ellipse cx="60" cy="106" rx="30" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M35 34 H85 V44 Q94 50 92 65 V94 Q91 102 82 102 H38 Q29 102 28 94 V65 Q26 50 35 44Z" fill="#edb0a3"/>
    <path d="M33 58 Q46 62 60 57 Q78 53 87 58 V93 Q87 97 81 97 H39 Q33 97 33 91Z" fill="#d9787d" stroke="none"/>
    <rect x="29" y="20" width="62" height="18" rx="5" fill="#b6cf9a"/>
    <path d="M38 24V34 M49 24V34 M60 24V34 M71 24V34 M82 24V34" stroke="#8eae76" stroke-width="2"/>
    <rect x="39" y="58" width="42" height="32" rx="7" fill="#fff0d6" stroke-width="2"/>
    <path d="M60 69 Q51 62 47 70 Q44 80 60 86 Q76 80 73 70 Q69 62 60 69Z" fill="#df7f80" stroke-width="1.8"/>
    <path d="M52 65 60 71 68 65 M60 69V62" stroke="#8fbd79" stroke-width="2.5"/>
    <path d="M36 47 35 54" stroke="#ffd6c6" stroke-width="4"/>`,

  honey: `
    <ellipse cx="58" cy="106" rx="35" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M32 44 H78 L83 58 Q91 64 88 90 Q86 103 56 103 Q26 103 24 90 Q21 64 29 58Z" fill="#f4c76b"/>
    <ellipse cx="55" cy="45" rx="24" ry="7" fill="#a98057"/>
    <path d="M36 50 Q41 61 46 53 Q49 49 54 57 V68 Q61 75 64 65 L66 55 Q70 59 74 51" fill="#f2b849" stroke="#d29a43" stroke-width="2.5"/>
    <path d="M64 43 86 21" stroke="#a98057" stroke-width="6"/>
    <g transform="rotate(42 88 25)"><rect x="77" y="11" width="22" height="30" rx="7" fill="#dfbd87" stroke-width="2.5"/><path d="M78 19H98 M78 26H98 M79 33H97" stroke="#a98057" stroke-width="2.5"/></g>
    <path d="M39 77 47 72 55 77 V86 L47 91 39 86Z M55 77 63 72 71 77 V86 L63 91 55 86Z" fill="#ffe2a1" stroke="#d7a149" stroke-width="2"/>
    <path d="M30 72V86" stroke="#ffe9ac" stroke-width="4"/>`,

  pasta: `
    <ellipse cx="60" cy="85" rx="47" ry="22" fill="#c4dfe3"/>
    <ellipse cx="60" cy="82" rx="39" ry="16" fill="#fff0d6" stroke-width="2.5"/>
    <path d="M27 81 Q29 65 42 70 Q58 75 54 63 Q50 55 65 58 Q80 60 77 72 Q71 83 90 81 M31 88 Q35 73 48 80 Q62 88 65 77 Q67 70 79 76 M40 91 Q46 85 57 91 Q71 96 82 87 M35 74 Q33 61 47 63 Q57 64 53 72" stroke="#765445" stroke-width="7"/>
    <path d="M27 81 Q29 65 42 70 Q58 75 54 63 Q50 55 65 58 Q80 60 77 72 Q71 83 90 81 M31 88 Q35 73 48 80 Q62 88 65 77 Q67 70 79 76 M40 91 Q46 85 57 91 Q71 96 82 87 M35 74 Q33 61 47 63 Q57 64 53 72" stroke="#f4d380" stroke-width="4"/>
    <path d="M84 59V18 M76 18V34 Q84 41 92 34 V18 M84 34V18" stroke="#9baeb6" stroke-width="3"/>
    <path d="M76 42 Q66 41 65 48 Q67 54 83 49 Q92 46 82 42 Q75 39 71 45 M73 51 Q79 58 72 63" stroke="#e4b961" stroke-width="3.5"/>
    <path d="M53 78 Q57 64 67 69 Q63 78 53 78Z" fill="#91bd7e" stroke-width="2"/>`,

  candy: `
    <path d="M36 47 14 34 18 56 11 75 35 72 M84 47 106 34 102 56 109 75 85 72" fill="#c4b0d9"/>
    <path d="M17 45 30 55 M17 65 31 62 M103 45 90 55 M103 65 89 62" stroke="#987fae" stroke-width="2.5"/>
    <rect x="31" y="37" width="58" height="46" rx="18" fill="#edacac"/>
    <path d="M39 40 Q47 56 41 80 M57 38 Q67 60 59 83 M76 39 Q85 56 79 79" stroke="#fff0d6" stroke-width="9"/>
    <rect x="31" y="37" width="58" height="46" rx="18" fill="none"/>
    <path d="M39 48 37 54" stroke="#ffd3c8" stroke-width="4"/>`,

  rock: `
    <ellipse cx="60" cy="105" rx="45" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M14 87 24 54 44 33 75 28 99 48 108 85 89 102 39 103Z" fill="#b7bec2"/>
    <path d="M24 54 54 49 75 28 M54 49 65 78 39 103 M65 78 108 85 M65 78 88 54 99 48" stroke="#8f9b9f" stroke-width="2.5"/>
    <path d="M54 49 75 28 99 48 88 54 65 78Z" fill="#d4d8d7" stroke="none"/>
    <path d="M54 49 75 28 99 48 88 54 65 78Z" stroke="#8f9b9f" stroke-width="2.5"/>
    <path d="M30 60 24 79 M41 40 50 36" stroke="#e4e6df" stroke-width="4"/>`,

  hill: `
    <path d="M12 94 Q28 70 45 73 Q76 37 108 92 V103 H12Z" fill="#b9d499" stroke="#8da477" stroke-width="2.5"/>
    <path d="M12 100 Q26 54 50 42 Q70 28 90 64 L108 103 H12Z" fill="#a4c88c"/>
    <path d="M46 101 Q66 81 66 64 Q66 51 58 45 Q77 59 77 75 Q77 92 69 103Z" fill="#ebd4a4" stroke="none"/>
    <path d="M24 88 27 81 29 89 M84 89 86 82 89 88" stroke="#7fa56d" stroke-width="2.5"/>
    <path d="M22 31 Q24 21 34 25 Q39 15 47 25 Q59 23 60 33 H22Z" fill="#f7f2df" stroke="#b7cfcd" stroke-width="2"/>`,

  beach: `
    <path d="M12 55 H108 V101 H12Z" fill="#9fd4df" stroke="none"/>
    <path d="M12 82 Q36 66 60 83 Q83 95 108 72 V105 H12Z" fill="#efd8a9" stroke="none"/>
    <path d="M12 79 Q36 64 60 81 Q83 93 108 69" stroke="#fff7e6" stroke-width="4"/>
    <path d="M68 59H100 M22 64H43" stroke="#d9eff0" stroke-width="2.5"/>
    <path d="M41 41 34 90" stroke="#a98057" stroke-width="3.5"/>
    <path d="M16 46 Q32 14 60 33 L70 47 Q57 42 51 51 Q39 43 32 50 Q23 43 16 46Z" fill="#eaa39b"/>
    <path d="M42 28 Q35 36 32 50 M42 28 Q50 36 51 51" stroke="#ffe3bd" stroke-width="3"/>
    <path d="M69 94 Q73 85 79 94 Q84 88 87 96" stroke="#c5aa7d" stroke-width="2.5"/>
    <circle cx="94" cy="27" r="11" fill="#f3d477" stroke="none"/>
    <path d="M20 99H23 M49 95H51 M95 101H98" stroke="#d1b787" stroke-width="2"/>`,

  sand: `
    <path d="M12 98 Q31 87 44 66 Q56 47 66 64 Q84 91 108 101 Q59 112 12 103Z" fill="#edce96"/>
    <path d="M37 88 Q48 77 54 66 M71 84 81 94" stroke="#fbe3b2" stroke-width="3"/>
    <path d="M24 94H26 M41 101H43 M62 93H64 M51 86H53 M82 103H84 M92 98H94 M61 77H63" stroke="#c8a879" stroke-width="2"/>
    <path d="M76 63 87 21" stroke="#b58b69" stroke-width="5"/>
    <path d="M82 21 84 12 H96 L94 25 H83" fill="#9ec9e0" stroke-width="2.5"/>
    <path d="M70 57 87 62 83 76 Q75 85 69 74Z" fill="#9ec9e0" stroke-width="2.5"/>
    <path d="M15 51 H42 L38 78 Q28 83 19 78Z" fill="#efa890" stroke-width="2.5"/>
    <path d="M18 52 Q18 34 29 34 Q41 34 40 52" stroke="#b99069" stroke-width="2.5"/>
    <ellipse cx="28" cy="51" rx="14" ry="4" fill="#f4d59d" stroke-width="2"/>`,

  mud: `
    <path d="M18 74 Q11 67 24 61 Q33 52 46 59 Q59 50 75 57 Q90 52 99 63 Q114 70 102 80 Q111 90 93 96 Q80 107 62 100 Q45 110 29 98 Q10 96 16 85 Q6 80 18 74Z" fill="#b58b69"/>
    <path d="M31 75 Q43 70 56 76 M70 86 Q83 81 95 85 M35 94 Q46 97 55 92" stroke="#d7b48b" stroke-width="3"/>
    <path d="M50 75 Q45 68 50 60 Q54 65 57 70 Q60 77 54 79Z M87 49 Q81 40 86 32 Q93 40 91 46Z M27 40 Q23 33 28 28 Q34 36 31 40Z" fill="#b58b69" stroke-width="2.5"/>
    <ellipse cx="76" cy="65" rx="7" ry="3" fill="#8f684f" stroke="none"/>
    <ellipse cx="23" cy="86" rx="5" ry="2" fill="#8f684f" stroke="none"/>
    <path d="M56 47 57 40 M72 36 76 28" stroke="#b58b69" stroke-width="3"/>`,

  ice: `
    <ellipse cx="60" cy="102" rx="45" ry="7" fill="#d4e9e8" stroke="none"/>
    <path d="M24 43 66 24 101 44 58 65Z" fill="#e5f3ee" stroke="#86aebc"/>
    <path d="M24 43 58 65 V102 L23 82Z" fill="#bcdde4" stroke="#86aebc"/>
    <path d="M58 65 101 44 V81 L58 102Z" fill="#9fcbd8" stroke="#86aebc"/>
    <path d="M31 50 39 55 M31 59V76 M66 68 72 65 M91 57V75 M40 39 61 30" stroke="#f1faf4" stroke-width="4"/>
    <path d="M79 47 83 43 80 35 M40 86 46 75 42 67" stroke="#88bacb" stroke-width="2"/>
    <path d="M14 91 Q10 96 14 99 Q19 99 18 95Z M106 87 Q101 93 104 97 Q110 99 109 93Z" fill="#bcdde4" stroke="#86aebc" stroke-width="2"/>`,

  wind: `
    <path d="M13 40 H72 Q86 40 86 28 Q86 17 75 17 Q64 17 65 28 M12 57 H94 Q107 57 107 46 Q107 35 97 36 M17 73 H65 Q80 73 80 86 Q80 98 67 98 Q58 98 58 89" stroke="#9dbfca" stroke-width="5"/>
    <path d="M32 21 46 30 M27 91 44 85" stroke="#bfd4d6" stroke-width="3"/>
    <path d="M84 89 Q97 70 110 75 Q108 93 91 95Z" fill="#b8cc86" stroke-width="2.5"/>
    <path d="M85 97 102 82" stroke="#819a67" stroke-width="2"/>
    <path d="M14 28 Q12 14 28 13 Q30 25 19 31Z" fill="#edc786" stroke-width="2.5"/>
    <path d="M18 33 23 20" stroke="#b89059" stroke-width="2"/>`,

  bag: `
    <ellipse cx="60" cy="106" rx="37" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M26 40 H94 L100 99 Q61 109 20 99Z" fill="#b6d0ab"/>
    <path d="M32 40 29 96 M88 40 91 96" stroke="#8fb58a" stroke-width="2.5"/>
    <path d="M43 48 V29 Q43 13 60 13 Q77 13 77 29 V48" stroke="#765445" stroke-width="8"/>
    <path d="M43 48 V29 Q43 13 60 13 Q77 13 77 29 V48" stroke="#e6cda2" stroke-width="4"/>
    <path d="M46 68 H74 V87 Q60 94 46 87Z" fill="#dce8c2" stroke-width="2.5"/>
    <path d="M50 72H70" stroke="#9cba8e" stroke-width="2"/>`,

  belt: `
    <path d="M17 53 Q57 38 100 48 L105 71 Q63 58 22 81Z" fill="#bc9471"/>
    <path d="M20 58 Q58 45 99 53 M24 75 Q59 61 101 66" stroke="#e0bd91" stroke-width="2"/>
    <path d="M42 48 Q71 29 103 45 L108 63 Q77 50 52 66Z" fill="#cba681"/>
    <path d="M54 50 Q79 39 100 49" stroke="#e5c9a3" stroke-width="2"/>
    <circle cx="73" cy="49" r="2" fill="#765445" stroke="none"/><circle cx="84" cy="49" r="2" fill="#765445" stroke="none"/><circle cx="95" cy="52" r="2" fill="#765445" stroke="none"/>
    <rect x="24" y="47" width="30" height="31" rx="5" transform="rotate(-13 39 62)" fill="#e9c574"/>
    <rect x="31" y="53" width="16" height="19" rx="2" transform="rotate(-13 39 62)" fill="#a88061" stroke-width="2.5"/>
    <path d="M37 62 57 57" stroke="#f7dea3" stroke-width="4"/>
    <path d="M60 45 66 64" stroke="#765445" stroke-width="6"/><path d="M60 45 66 64" stroke="#bc9471" stroke-width="3"/>`,

  shorts: `
    <path d="M28 24 H92 L103 96 70 102 60 65 50 102 17 96Z" fill="#9abdd5"/>
    <path d="M28 24H92L93 37H27Z" fill="#bfd8e3"/>
    <path d="M32 38 Q33 56 22 62 M88 38 Q87 56 98 62 M60 38V65" stroke="#739dbd" stroke-width="2.5"/>
    <path d="M18 88 51 94 M69 94 102 88" stroke="#cbdfe6" stroke-width="5"/>
    <path d="M55 29H65 M53 40 60 44 68 40" stroke-width="2.5"/>
    <path d="M47 27V34 M73 27V34" stroke="#789db7" stroke-width="2"/>`,

  mitten: `
    <ellipse cx="60" cy="108" rx="28" ry="3" fill="#eadbc5" stroke="none"/>
    <path d="M35 86 Q21 77 20 62 Q19 50 29 48 Q38 48 40 61 V37 Q40 15 62 15 Q84 15 85 37 L85 73 Q85 84 76 92Z" fill="#e5a0a4"/>
    <path d="M43 60 44 78" stroke="#c78288" stroke-width="2.5"/>
    <path d="M34 87 80 91 77 107 31 103Z" fill="#c19dc5"/>
    <path d="M39 90 37 102 M49 91 47 103 M59 92 57 104 M69 93 67 104" stroke="#ecd0dd" stroke-width="3"/>
    <path d="M62 41V65 M50 53H74 M53 44 71 62 M53 62 71 44" stroke="#f7d9cb" stroke-width="2.5"/>
    <path d="M48 28 Q52 22 60 22" stroke="#f7c6bc" stroke-width="4"/>`,

  cape: `
    <path d="M44 24 Q60 16 76 24 L104 100 Q82 96 60 105 Q38 96 16 100Z" fill="#cf8eaa"/>
    <path d="M48 31 34 89 M59 35 60 93 M72 31 88 89" stroke="#af7295" stroke-width="3"/>
    <path d="M43 24 Q60 11 77 24 L70 37 60 31 50 37Z" fill="#e6adc0"/>
    <path d="M48 24 Q60 19 72 24 L66 28 H54Z" fill="#8c7088" stroke-width="2.5"/>
    <circle cx="56" cy="34" r="3" fill="#f1ce75" stroke-width="2"/><circle cx="64" cy="34" r="3" fill="#f1ce75" stroke-width="2"/>
    <path d="M59 34H61 M55 37 47 47 M65 37 73 47" stroke="#f1ce75" stroke-width="2.5"/>`,

  van: `
    <ellipse cx="60" cy="104" rx="45" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M13 84 V39 Q13 31 23 31 H76 Q83 31 86 39 L102 61 Q108 66 108 75 V88 H13Z" fill="#afd0bf"/>
    <rect x="23" y="42" width="24" height="20" rx="3" fill="#e1f0ee" stroke-width="2.5"/>
    <path d="M59 42 H77 L89 61 H59Z" fill="#d2e9eb" stroke-width="2.5"/>
    <path d="M54 37V83 M61 69H69 M17 73H46" stroke="#769f90" stroke-width="2.5"/>
    <rect x="99" y="70" width="8" height="9" rx="2" fill="#f8d98a" stroke-width="2"/>
    <circle cx="32" cy="88" r="13" fill="#777a7a"/><circle cx="88" cy="88" r="13" fill="#777a7a"/>
    <circle cx="32" cy="88" r="6" fill="#d5d5c9" stroke-width="2"/><circle cx="88" cy="88" r="6" fill="#d5d5c9" stroke-width="2"/>`,

  taxi: `
    <ellipse cx="60" cy="104" rx="45" ry="4" fill="#eadbc5" stroke="none"/>
    <rect x="49" y="22" width="23" height="10" rx="3" fill="#f7e4ad" stroke-width="2.5"/>
    <path d="M13 72 Q14 62 27 61 L39 38 Q42 32 50 32 H72 Q78 32 82 39 L94 61 Q107 63 108 73 V86 H12Z" fill="#f3ce6c"/>
    <path d="M44 40H58V60H34Z M65 40H74L86 60H65Z" fill="#d7e9e8" stroke-width="2.5"/>
    <path d="M26 66H94" stroke="#765445" stroke-width="7"/>
    <path d="M31 66H37 M44 66H50 M57 66H63 M70 66H76 M83 66H89" stroke="#fff0d6" stroke-width="6" stroke-linecap="butt"/>
    <path d="M61 73V82 M68 75H74" stroke-width="2"/>
    <path d="M14 74H22 M99 74H107" stroke="#fff0c5" stroke-width="6"/>
    <circle cx="33" cy="88" r="12" fill="#777a7a"/><circle cx="88" cy="88" r="12" fill="#777a7a"/>
    <circle cx="33" cy="88" r="5" fill="#f6e6c8" stroke="none"/><circle cx="88" cy="88" r="5" fill="#f6e6c8" stroke="none"/>`,

  wheel: `
    <ellipse cx="60" cy="107" rx="33" ry="3" fill="#eadbc5" stroke="none"/>
    <circle cx="60" cy="60" r="44" fill="#7a8084"/>
    <circle cx="60" cy="60" r="31" fill="#d1d9d8"/>
    <circle cx="60" cy="60" r="24" fill="#a8b7bf" stroke-width="2.5"/>
    <path d="M60 38V82 M38 60H82 M44 44 76 76 M44 76 76 44" stroke="#e5e9df" stroke-width="5"/>
    <circle cx="60" cy="60" r="10" fill="#e2d9be" stroke-width="2.5"/>
    <circle cx="60" cy="60" r="3" fill="#9ba6aa" stroke="none"/>
    <path d="M30 30 35 35 M60 17V24 M90 30 85 35 M103 60H96 M90 90 85 85 M60 103V96 M30 90 35 85 M17 60H24" stroke="#565f63" stroke-width="3"/>`,

  yoyo: `
    <path d="M65 15 Q78 12 78 23 Q78 32 68 31 Q62 27 65 15Z M68 31 Q53 50 70 58 Q92 70 72 83" stroke="#bca88b" stroke-width="2.5"/>
    <ellipse cx="69" cy="80" rx="28" ry="25" fill="#e8aa8d"/>
    <path d="M47 68 38 64 M47 98 37 95" stroke="#765445" stroke-width="4"/>
    <ellipse cx="47" cy="80" rx="29" ry="27" fill="#e69b98"/>
    <ellipse cx="47" cy="80" rx="19" ry="18" fill="#f2c0ad" stroke-width="2.5"/>
    <circle cx="47" cy="80" r="7" fill="#f5d986" stroke-width="2.5"/>
    <path d="M30 67 Q36 61 42 60" stroke="#ffdcc4" stroke-width="4"/>
    <path d="M90 50 96 42 M94 63 104 61" stroke="#c8c6ad" stroke-width="2.5"/>`,

  dice: `
    <path d="M60 22 88 12 108 29 79 40Z" fill="#eee0c2"/>
    <path d="M60 22 79 40 V70 L59 51Z" fill="#d2bdda"/>
    <path d="M79 40 108 29 V60 L79 70Z" fill="#e3cde4"/>
    <ellipse cx="85" cy="26" rx="3" ry="2" fill="#765445" stroke="none"/>
    <ellipse cx="88" cy="49" rx="2.5" ry="3.5" fill="#765445" stroke="none"/><ellipse cx="100" cy="43" rx="2.5" ry="3.5" fill="#765445" stroke="none"/><ellipse cx="99" cy="56" rx="2.5" ry="3.5" fill="#765445" stroke="none"/>
    <path d="M14 55 47 43 76 61 42 75Z" fill="#fff0d6"/>
    <path d="M14 55 42 75 V106 L14 85Z" fill="#dfb18f"/>
    <path d="M42 75 76 61 V93 L42 106Z" fill="#f1d1a2"/>
    <ellipse cx="36" cy="58" rx="3" ry="2" fill="#765445" stroke="none"/><ellipse cx="53" cy="62" rx="3" ry="2" fill="#765445" stroke="none"/>
    <ellipse cx="23" cy="69" rx="2.5" ry="3.5" fill="#765445" stroke="none"/><ellipse cx="34" cy="91" rx="2.5" ry="3.5" fill="#765445" stroke="none"/>
    <path d="M51 78V79 M67 72V73 M59 85V86 M51 95V96 M67 90V91" stroke="#765445" stroke-width="5"/>`,

  swing: `
    <path d="M17 105 32 23 51 105 M70 105 88 23 106 105" stroke="#765445" stroke-width="7"/>
    <path d="M17 105 32 23 51 105 M70 105 88 23 106 105" stroke="#afc99b" stroke-width="4"/>
    <path d="M21 83H45 M76 83H101 M31 23H89" stroke="#765445" stroke-width="7"/>
    <path d="M21 83H45 M76 83H101 M31 23H89" stroke="#afc99b" stroke-width="4"/>
    <path d="M46 25V84 M76 25V84" stroke="#c8a778" stroke-width="3"/>
    <path d="M40 82 H83 L79 91 H43Z" fill="#e7ab87"/>
    <path d="M43 84H79" stroke="#f6cfa7" stroke-width="2"/>
    <circle cx="32" cy="23" r="4" fill="#e4d5b5" stroke-width="2"/><circle cx="88" cy="23" r="4" fill="#e4d5b5" stroke-width="2"/>`,

  slide: `
    <path d="M20 103 40 31 M36 102 51 40" stroke="#765445" stroke-width="7"/>
    <path d="M20 103 40 31 M36 102 51 40" stroke="#9ebfc9" stroke-width="4"/>
    <path d="M25 84H40 M30 66H44 M35 48H48" stroke="#95b7c2" stroke-width="4"/>
    <path d="M40 36 H56 Q64 51 76 71 Q90 95 108 95 L106 105 Q82 107 65 80 L44 45 H39Z" fill="#efbb76"/>
    <path d="M47 37 71 75 Q88 100 106 100" stroke="#fce1a1" stroke-width="4"/>
    <path d="M38 36V20 H55 V35 M59 43V31 Q66 40 72 50" stroke="#a5c3c8" stroke-width="4"/>
    <path d="M76 81V104 M70 100H82" stroke="#9ebfc9" stroke-width="4"/>
    <path d="M13 108H109" stroke="#bcd0a1" stroke-width="3"/>`,

  tent: `
    <path d="M13 100 52 25 77 21 108 99Z" fill="#e9b17c"/>
    <path d="M52 25 82 100 H13Z" fill="#f5ce90"/>
    <path d="M52 47 29 100 H70Z" fill="#a6846c"/>
    <path d="M52 47 54 99 H70Z" fill="#846e61" stroke="none"/>
    <path d="M52 25 51 14 M77 21 80 12 M20 88 11 105 M101 87 109 105" stroke="#9c805e" stroke-width="2.5"/>
    <path d="M54 27 77 23 105 96" stroke="#f9d8a9" stroke-width="3"/>
    <path d="M33 100 51 70 53 100Z" fill="#f5d99e" stroke="none"/>
    <path d="M13 106H106" stroke="#adbf8c" stroke-width="3"/>`,

  box: `
    <path d="M19 41 57 24 99 43 61 61Z" fill="#e8c391"/>
    <path d="M19 41 61 61 V105 L19 83Z" fill="#dcb583"/>
    <path d="M61 61 99 43 V86 L61 105Z" fill="#cba170"/>
    <path d="M19 41 12 27 51 12 57 24Z M57 24 71 12 109 28 99 43Z M19 41 61 61 49 76 12 55Z M61 61 99 43 109 57 74 78Z" fill="#efd0a0"/>
    <path d="M57 27 61 57 M22 81 55 98 M66 98 94 84" stroke="#b58b61" stroke-width="2"/>
    <rect x="29" y="76" width="18" height="9" rx="1" transform="skewY(26) translate(0 -18)" fill="#f8e5c0" stroke="none"/>`,

  pen: `
    <g transform="rotate(37 60 60)">
      <path d="M52 29 H68 V91 L60 107 52 91Z" fill="#9cbcd3"/>
      <path d="M52 83H68V92L60 105 52 92Z" fill="#d8ded6" stroke-width="2.5"/>
      <path d="M60 104V108" stroke="#765445" stroke-width="3"/>
      <rect x="51" y="13" width="18" height="38" rx="5" fill="#86abc6"/>
      <path d="M62 18 V42 Q62 48 70 46" stroke="#e2e6db" stroke-width="3"/>
      <path d="M57 55V77" stroke="#cde1e7" stroke-width="3"/>
      <path d="M53 51H67" stroke="#e6d6ad" stroke-width="3"/>
    </g>`,

  pencil: `
    <g transform="rotate(38 60 60)">
      <path d="M50 30 H70 V88 L60 110 50 88Z" fill="#f3ce6c"/>
      <path d="M57 34V88 M64 34V88" stroke="#c99f4e" stroke-width="2"/>
      <path d="M50 88H70L60 110Z" fill="#edd1a2"/>
      <path d="M56 101H64L60 110Z" fill="#77736d" stroke-width="2"/>
      <path d="M50 16 Q50 10 56 10 H64 Q70 10 70 16 V24 H50Z" fill="#eaa5a1"/>
      <path d="M50 24H70V34H50Z" fill="#ccd6d6" stroke-width="2.5"/>
      <path d="M51 29H69" stroke="#99acb2" stroke-width="2"/>
    </g>`,

  pan: `
    <path d="M67 53 96 18 Q101 12 106 17 Q110 21 105 27 L79 64Z" fill="#a88465"/>
    <path d="M95 23 102 18" stroke="#d7b087" stroke-width="2.5"/>
    <path d="M16 76 Q20 99 51 104 Q79 108 94 86 V76Z" fill="#8c9a9e"/>
    <ellipse cx="55" cy="75" rx="40" ry="25" fill="#b5c4c7"/>
    <ellipse cx="55" cy="73" rx="31" ry="17" fill="#7e919b" stroke-width="2.5"/>
    <path d="M32 75 Q26 65 40 62 Q51 55 60 62 Q74 62 76 73 Q73 84 60 84 Q39 89 32 75Z" fill="#fff3d7" stroke-width="2"/>
    <ellipse cx="54" cy="72" rx="10" ry="8" fill="#efc163" stroke="#d4a452" stroke-width="2"/>
    <path d="M26 88 Q35 97 48 98" stroke="#cbd8d5" stroke-width="3"/>`,

  pot: `
    <ellipse cx="60" cy="105" rx="34" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M29 57 H17 Q9 58 12 70 Q15 78 28 74 M91 57 H103 Q111 58 108 70 Q105 78 92 74" fill="#c49b76"/>
    <path d="M26 48 H94 V83 Q94 103 60 103 Q26 103 26 83Z" fill="#a5c6c3"/>
    <ellipse cx="60" cy="48" rx="35" ry="11" fill="#cce0d4"/>
    <path d="M27 48 Q34 27 60 27 Q86 27 93 48Z" fill="#b9d5cc"/>
    <path d="M51 28V20 Q60 15 69 20 V28" fill="#bc9974" stroke-width="3"/>
    <path d="M37 63V83 Q37 93 49 96" stroke="#d8e8d8" stroke-width="4"/>
    <path d="M82 64V83" stroke="#7ea9a9" stroke-width="2.5"/>`,

  comb: `
    <g transform="rotate(-20 60 60)">
      <path d="M19 40 H101 Q108 40 108 47 V54 H12 V47 Q12 40 19 40Z" fill="#df9ea2"/>
      <path d="M16 54V85 M25 54V85 M34 54V85 M43 54V85 M52 54V85 M61 54V85 M70 54V85 M79 54V85 M88 54V85 M97 54V85 M105 54V85" stroke="#765445" stroke-width="6"/>
      <path d="M16 54V85 M25 54V85 M34 54V85 M43 54V85 M52 54V85 M61 54V85 M70 54V85 M79 54V85 M88 54V85 M97 54V85 M105 54V85" stroke="#eab4b5" stroke-width="3"/>
      <path d="M20 46H99" stroke="#f7cdca" stroke-width="3"/>
    </g>`,

  fan: `
    <path d="M55 78H65V99H55Z" fill="#b8cece"/>
    <path d="M38 100 Q60 91 82 100 L87 108 H33Z" fill="#9abbbb"/>
    <circle cx="60" cy="47" r="36" fill="#e0ede4"/>
    <path d="M60 47 Q35 37 45 20 Q52 12 62 20 Q70 28 60 47 M60 47 Q82 31 91 48 Q95 59 82 65 Q71 67 60 47 M60 47 Q66 73 47 76 Q34 75 37 62 Q40 52 60 47" fill="#8dbec5" stroke-width="2.5"/>
    <circle cx="60" cy="47" r="30" stroke="#b7cecc" stroke-width="2"/>
    <path d="M24 47H96 M60 11V83 M35 22 85 72 M35 72 85 22" stroke="#b7cecc" stroke-width="2"/>
    <circle cx="60" cy="47" r="8" fill="#ebc387" stroke-width="2.5"/>
    <circle cx="72" cy="103" r="2" fill="#765445" stroke="none"/>`,

  mop: `
    <path d="M59 80 81 14" stroke="#765445" stroke-width="8"/><path d="M59 80 81 14" stroke="#b4c9ad" stroke-width="4"/>
    <path d="M50 77 66 82 63 91 46 86Z" fill="#dfb77e"/>
    <path d="M49 85 Q34 86 21 103 M52 88 Q43 94 38 108 M57 90 56 109 M62 90 Q68 96 72 108 M65 89 Q80 93 91 104" stroke="#765445" stroke-width="9"/>
    <path d="M49 85 Q34 86 21 103 M52 88 Q43 94 38 108 M57 90 56 109 M62 90 Q68 96 72 108 M65 89 Q80 93 91 104" stroke="#d2dfd7" stroke-width="6"/>
    <path d="M45 90 32 107 M59 93 64 109 M67 93 81 107" stroke="#eaf0dd" stroke-width="4"/>
    <path d="M16 108H96" stroke="#b7dbdf" stroke-width="2.5"/>`,

  rug: `
    <path d="M28 24 105 42 92 99 14 78Z" fill="#dda69f"/>
    <path d="M34 34 94 48 85 87 25 73Z" fill="#f3d8b2"/>
    <path d="M61 43 81 65 60 80 40 58Z" fill="#a8c4b0"/>
    <path d="M61 52 71 64 60 71 50 59Z" fill="#d69d9a" stroke-width="2"/>
    <path d="M27 27 20 24 M25 35 18 32 M23 44 16 41 M21 52 14 49 M19 61 12 58 M17 70 10 67 M103 47 110 49 M101 55 108 57 M99 64 106 66 M97 72 104 74 M95 81 102 83 M93 90 100 92" stroke="#b88985" stroke-width="2"/>
    <path d="M39 41 43 42 M82 52 86 53 M33 67 37 68 M75 79 79 80" stroke="#c18d85" stroke-width="3"/>`,

  jug: `
    <ellipse cx="55" cy="106" rx="30" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M78 40 Q106 34 108 62 Q109 87 80 85 L79 73 Q97 75 97 62 Q96 48 81 51Z" fill="#a9c8d1"/>
    <path d="M26 23 H79 L77 48 Q82 65 85 88 Q84 104 55 104 Q26 104 25 89 Q27 66 33 50 L29 35 16 29Z" fill="#bcd9dc"/>
    <path d="M17 29 Q43 33 77 25" stroke="#87acb9" stroke-width="2.5"/>
    <path d="M32 75 Q55 64 80 74 V89 Q78 98 55 98 Q34 98 32 89Z" fill="#93bac7" stroke="none"/>
    <path d="M40 42 37 57 M35 67 33 77" stroke="#e4f1e7" stroke-width="4"/>
    <path d="M64 41H71 M62 53H72 M64 65H75" stroke="#86aebc" stroke-width="2"/>`,

  toe: `
    <path d="M28 15H52V57 Q58 69 75 74 L95 80 Q107 80 109 89 Q111 100 98 102 H36 Q17 101 17 86 Q18 76 24 68Z" fill="#e4c3ac" stroke="#a58b79" stroke-width="2.5"/>
    <path d="M90 81 Q106 78 109 89 Q111 100 98 102 H89 Q84 91 90 81Z" fill="#f3c8a8"/>
    <path d="M97 83 Q105 83 105 90 Q100 95 95 89Z" fill="#fae1c9" stroke-width="2"/>
    <path d="M29 73 Q35 68 41 72 M36 92 Q58 98 79 94" stroke="#c9a18b" stroke-width="2"/>
    <circle cx="98" cy="91" r="17" fill="none" stroke="#e9ad45" stroke-width="3"/>
    <path d="M62 86H77 m-6 -5 6 5 -6 5" fill="none" stroke="#dca83d" stroke-width="3"/>`,

  neck: `
    <path d="M18 108 V96 Q21 83 43 79 L48 73 H72 L77 79 Q99 83 102 96 V108Z" fill="#b8d0cb" stroke="#91aaa8" stroke-width="2.5"/>
    <path d="M47 60 V77 Q60 92 73 77 V60Z" fill="#f1c6a6"/>
    <path d="M47 62 Q60 70 73 62 V69 Q60 77 47 69Z" fill="#deb092" stroke="none"/>
    <path d="M32 37 Q29 13 60 12 Q91 13 88 37 L86 47 Q80 65 60 69 Q40 65 34 47Z" fill="#ead0b8" stroke="#ac917c" stroke-width="2.5"/>
    <path d="M33 34 Q25 18 46 11 Q70 6 86 21 L89 38 80 29 Q59 37 42 25 L36 37Z" fill="#a99177" stroke="#8f7969" stroke-width="2.5"/>
    <path d="M43 43H48 M72 43H77 M55 56 Q60 59 65 56" stroke="#a18571" stroke-width="2"/>
    <path d="M36 84 Q60 106 84 84" stroke="#e0e9dd" stroke-width="4"/>
    ${spotlight(60, 75, 16, 106)}`
};
