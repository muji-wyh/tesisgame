const shadow = '<ellipse cx="60" cy="106" rx="43" ry="4" fill="#eadbc5" stroke="none"/>';
const eye = (x, y) => `<circle cx="${x}" cy="${y}" r="2.6" fill="#765445" stroke="none"/>`;
const dots = (points, fill, radius = 3) => points.map(([x, y]) => `<circle cx="${x}" cy="${y}" r="${radius}" fill="${fill}" stroke="none"/>`).join('');
const stars = '<path d="M20 21v8m-4-4h8 M97 27v8m-4-4h8 M91 92v6m-3-3h6" stroke="#d5ac61" stroke-width="2.5"/>';

// Original noun-specific vector silhouettes, using the shared word-card palette.
module.exports = {
  crocodile: `${shadow}
    <path d="M37 77Q19 81 10 56L42 64Q59 43 84 64L107 67V83L74 89H35Z" fill="#97bd79"/>
    <path d="M18 64 23 55 29 65 34 54 41 63 46 52 54 59 60 51 68 59" fill="#6a9b6b"/>
    <path d="M41 83 34 100H49L55 86 M70 85 75 101H89L83 85" fill="#97bd79"/>
    <path d="M79 78H107 M87 78 91 85 95 78 100 84 104 78" fill="#fff5df" stroke-width="2"/>
    <circle cx="80" cy="62" r="8" fill="#97bd79"/>${eye(82, 62)}${eye(103, 70)}`,
  rhinoceros: `${shadow}
    <path d="M21 64Q19 41 48 37Q73 34 89 55L99 63 105 77Q99 88 81 86L75 99H62L59 84H44L40 100H25V81Z" fill="#abb3bd"/>
    <path d="M85 66 91 42 96 66Z" fill="#fff1d4"/>
    <path d="M100 69 105 54 108 72Z" fill="#f4dfbb"/>
    <path d="M73 52 70 34Q83 31 84 45Z" fill="#c4c8ce"/>
    <path d="M21 61 12 56 10 63 M57 41Q47 60 54 82 M83 79H102" stroke-width="2.5"/>
    ${eye(83, 66)}`,
  chameleon: `${shadow}
    <path d="M31 66Q6 55 13 86Q21 107 37 91Q46 77 33 76Q23 75 25 85" stroke="#87b976" stroke-width="12"/>
    <path d="M30 75Q29 39 59 42L82 31 97 57 109 67 96 77H42Z" fill="#9fc97e"/>
    <path d="M36 49 40 36 47 44 52 32 58 42 64 29 70 38" fill="#76a96e"/>
    <path d="M44 71 43 95H54 M74 73 76 94H88" stroke="#79a86b" stroke-width="7"/>
    <circle cx="86" cy="56" r="12" fill="#d3dc93"/>${eye(89, 56)}
    <path d="M93 69H108 M22 98H100" stroke-width="3"/>
    ${dots([[44,59],[57,64],[69,54]], '#e4d782', 4)}`,
  armadillo: `${shadow}
    <path d="M27 84Q9 87 11 98Q30 100 42 89" fill="#c49a82"/>
    <path d="M28 81Q23 42 58 37Q88 35 91 73L78 89H40Z" fill="#bda78e"/>
    <path d="M41 42Q28 65 43 87 M52 38Q39 66 54 89 M64 39Q51 65 65 87 M76 44Q63 67 75 83" stroke="#8d7565" stroke-width="4"/>
    <path d="M78 64 77 38 88 55 94 43 97 65 111 80Q107 87 91 86L79 79Z" fill="#d2b59c"/>
    <path d="M39 87 34 100H46L51 88 M73 87 69 100H81L85 86" fill="#c49a82"/>
    ${eye(97, 73)}${eye(110, 81)}`,
  porcupine: `${shadow}
    <path d="M24 84 13 61 25 66 19 42 34 53 35 26 46 45 56 20 62 43 78 25 75 47 95 40 84 62 100 58 91 81Z" fill="#c8a786"/>
    <path d="M23 79Q29 56 53 56Q76 54 86 71L107 84Q109 94 93 95H37Q22 92 23 79Z" fill="#ad8366"/>
    <path d="M39 69 31 48 M50 68 47 39 M63 68 68 43 M72 75 84 58" stroke="#eee0ba" stroke-width="3"/>
    <path d="M39 93V103H49 M75 95V103H87" stroke-width="5"/>${eye(92, 82)}${eye(106, 88)}`,
  centipede: `${shadow}
    <path d="M19 77 13 94 M30 79 25 100 M43 77 41 98 M56 70 57 93 M68 59 76 78 M79 52 91 67 M24 64 13 54 M38 64 28 49 M51 59 44 43 M63 49 59 33 M74 42 78 26" stroke="#c09463" stroke-width="3"/>
    <path d="M17 71Q40 81 55 66T83 49" stroke="#d99f6a" stroke-width="17"/>
    <path d="M28 65 26 80 M41 66 41 80 M53 57 61 68 M66 46 75 59" stroke="#a77b58" stroke-width="3"/>
    <ellipse cx="91" cy="42" rx="15" ry="13" fill="#e9b37f"/>
    <path d="M88 30 85 19 M98 31 106 23"/>${eye(93, 39)}${eye(101, 44)}`,
  dragonfly: `
    <path d="M56 52Q19 12 13 32Q11 51 54 61 M65 53Q101 13 108 32Q111 52 65 62" fill="#d1e8ed"/>
    <path d="M54 64Q16 55 18 77Q25 89 55 71 M66 64Q104 55 104 77Q97 89 65 72" fill="#b9dce4"/>
    <path d="M25 35 51 54 M95 35 70 54 M30 72 50 66 M91 72 71 66" stroke="#94bccb" stroke-width="2"/>
    <path d="M57 55H64L66 94 60 107 54 94Z" fill="#89b9a7"/>
    <path d="M56 75H65 M56 86H65 M57 96H63" stroke-width="2"/>
    <circle cx="60" cy="48" r="10" fill="#99cbb5"/>
    <circle cx="53" cy="44" r="6" fill="#b8d98f"/><circle cx="67" cy="44" r="6" fill="#b8d98f"/>
    ${eye(52,44)}${eye(68,44)}`,
  hedgehog: `${shadow}
    <path d="M18 86 13 71 22 68 20 54 30 54 35 39 44 46 56 33 63 45 77 38 78 52 91 54 85 70 91 87Z" fill="#aa8267"/>
    <path d="M23 89Q36 61 62 66L83 72 108 88Q111 96 94 99H43Q28 98 23 89Z" fill="#e5c19a"/>
    <path d="M31 69 37 77 M41 57 46 66 M55 51 59 61 M71 55 73 64" stroke="#e3c09c" stroke-width="3"/>
    <path d="M43 98 41 104H50 M79 99 79 105H89" stroke-width="4"/>
    ${eye(87,83)}${eye(108,90)}`,
  woodpecker: `
    <path d="M87 13H108V107H82Z" fill="#c29572"/><path d="M97 22 94 43 M96 70 101 95" stroke="#9b7559"/>
    <path d="M50 86 28 107 40 79" fill="#536c77"/>
    <path d="M34 66Q30 40 54 39Q77 43 72 70L60 93Q35 97 34 66Z" fill="#fcf3db"/>
    <path d="M39 46Q59 45 55 82L37 86Q25 65 39 46Z" fill="#586c74"/>
    <path d="M47 56 35 72 M50 66 40 80" stroke="#fcf3db" stroke-width="3"/>
    <circle cx="61" cy="35" r="17" fill="#fcf3db"/>
    <path d="M47 23 58 13 73 19 76 30 59 25Z" fill="#d97670"/>
    <path d="M76 32 94 39 76 43Z" fill="#c49a62"/>
    <path d="M61 88 83 81 M63 94 82 91"/>${eye(67,33)}`,
  pelican: `${shadow}
    <path d="M22 88Q14 65 37 62Q65 58 76 73L82 91Q60 107 33 99Z" fill="#fff1d9"/>
    <path d="M38 73Q55 65 63 90Q43 98 28 88" fill="#e4d5bf"/>
    <path d="M67 77Q58 58 67 32Q78 17 91 32L86 57Q80 67 83 80" fill="#fff1d9"/>
    <path d="M84 40 112 49 83 63Q77 54 84 40Z" fill="#e9b577"/>
    <path d="M85 41 112 49 83 50" fill="#f7ce8b"/>
    <path d="M40 100 34 109H49 M64 100 58 109H74" fill="#e4ac70"/>
    ${eye(80,36)}`,
  artichoke: `${shadow}
    <path d="M56 86 53 106H65L64 86" fill="#84aa6e"/>
    <path d="M60 93Q21 84 24 50L42 61 37 34 54 49 60 19 69 48 86 33 78 61 98 48Q102 83 60 93Z" fill="#8fba7b"/>
    <path d="M26 51Q28 74 60 92Q38 72 42 60 M97 50Q92 79 60 92Q81 70 78 60 M42 59Q42 76 60 90Q55 67 54 49 M78 60Q76 76 60 90L69 48" stroke="#688e62"/>
    <path d="M54 50 60 71 69 49" fill="#c1d493"/>`,
  asparagus: `${shadow}
    <path d="M31 101 45 40 M48 104 61 36 M67 103 80 39" stroke="#83ad6e" stroke-width="12"/>
    <path d="M37 42 43 17 50 37 45 49Z M54 38 62 12 68 33 62 46Z M73 41 82 20 88 39 79 50Z" fill="#96b77a"/>
    <path d="M40 35 46 30 49 36 M58 30 64 25 67 32 M77 36 83 31 87 37 M38 65 44 69 M35 83 40 87 M54 62 60 66 M49 83 55 87 M74 67 79 71 M70 85 75 89" stroke="#5e8e64" stroke-width="2.5"/>
    <path d="M29 76 78 85 76 93 28 84Z" fill="#dfb681"/>`,
  eggplant: `${shadow}
    <path d="M72 37Q91 47 87 70Q81 103 43 106Q20 106 22 85Q24 68 46 60L61 40Z" fill="#9b82b8"/>
    <path d="M67 39 62 27 73 33 83 24 82 38 94 45 81 49 75 62 69 49 56 51Z" fill="#91b67c"/>
    <path d="M78 33Q83 21 91 18" stroke="#6f9666" stroke-width="5"/>
    <path d="M32 87Q39 74 53 73" stroke="#c6abd7" stroke-width="6"/>`,
  cinnamon: `${shadow}
    <path d="M24 82 77 23Q87 19 94 28L41 91Z" fill="#c4946b"/>
    <path d="M38 96 88 40Q100 35 104 48L53 104Z" fill="#b88159"/>
    <path d="M27 82 78 28 M43 97 94 44" stroke="#e4b78b" stroke-width="3"/>
    <ellipse cx="32" cy="87" rx="11" ry="7" transform="rotate(39 32 87)" fill="#e4b78b"/>
    <ellipse cx="46" cy="101" rx="10" ry="6" transform="rotate(39 46 101)" fill="#d9ac7d"/>
    <path d="M29 84Q41 87 34 92Q29 94 29 88 M43 99Q53 102 47 105" stroke="#936341" stroke-width="2.5"/>
    <path d="M25 52Q11 31 29 23Q40 32 34 48Z" fill="#a6bd83"/>`,
  pistachio: `${shadow}
    <path d="M33 91Q8 69 24 40Q39 19 58 35Q79 20 95 41Q107 68 83 95L60 106Z" fill="#ead4a9"/>
    <path d="M58 35Q34 53 40 79L60 102Q81 82 82 62Q83 43 58 35Z" fill="#b1c47a"/>
    <path d="M58 36Q48 63 60 102 M28 42Q18 65 34 83 M91 46Q100 64 88 83" stroke="#f9ebc9" stroke-width="4"/>
    <path d="M41 62Q48 45 58 39 M69 85 74 66" stroke="#809a5e" stroke-width="3"/>`,
  hazelnut: `${shadow}
    <path d="M48 30Q21 33 17 59Q12 88 36 99Q60 111 79 88Q93 63 71 41L57 24Z" fill="#c08e61"/>
    <path d="M24 81Q46 71 75 82Q67 108 44 103Q26 98 24 81Z" fill="#e1c397"/>
    <path d="M31 84 35 93 M43 82 47 97 M56 83 59 96 M67 85 68 91" stroke="#ba996f" stroke-width="2"/>
    <path d="M26 64Q28 44 44 40 M61 39Q77 54 75 69" stroke="#e2b586" stroke-width="4"/>
    <path d="M80 69Q106 63 110 85Q107 105 87 106Q69 97 80 69Z" fill="#f3dfb7"/>
    <path d="M85 79Q95 72 101 86Q102 99 89 99Q79 90 85 79Z" fill="#d3ac77"/>
    <path d="M64 26Q89 12 101 32Q77 45 64 26Z" fill="#9dbd7d"/>`,
  raspberry: `${shadow}
    <path d="M39 39 32 23 48 29 60 16 68 29 86 24 81 43Z" fill="#94b97c"/>
    <path d="M30 39Q60 24 92 41L87 76Q80 99 60 107Q40 98 30 76Z" fill="#cf7080"/>
    ${[[39,44],[56,41],[75,42],[87,53],[30,60],[48,60],[67,59],[80,73],[36,78],[55,79],[64,95]].map(([x,y])=>`<circle cx="${x}" cy="${y}" r="10" fill="#e68a99" stroke-width="2"/>`).join('')}
    ${dots([[36,40],[52,38],[27,56],[45,57],[52,75]], '#f5b0ba', 2.5)}`,
  blueberry: `${shadow}
    <path d="M54 27Q73 13 90 22Q86 38 65 41Z" fill="#91b781"/>
    <circle cx="41" cy="63" r="27" fill="#9aa5cd"/><circle cx="82" cy="70" r="27" fill="#8296c5"/>
    <circle cx="57" cy="87" r="24" fill="#8b9fc8"/>
    <path d="M36 46 43 52 52 48 47 57 50 65 40 61 32 66 34 56 28 51Z M80 52 86 57 95 55 91 64 95 71 85 67 77 73 78 64 73 59Z M53 73 59 78 66 75 64 83 69 89 60 87 54 94 53 85 47 81Z" fill="#677da9" stroke-width="2"/>
    <path d="M20 60 22 52 M67 51 72 47 M39 89 40 82" stroke="#c8d4e7" stroke-width="4"/>`,
  grapefruit: `${shadow}
    <circle cx="46" cy="59" r="35" fill="#f0ce79"/>
    <path d="M28 37Q35 27 47 27" stroke="#fae7a9" stroke-width="5"/>
    <path d="M47 24Q47 10 59 12" stroke="#88a772" stroke-width="4"/>
    <circle cx="78" cy="79" r="30" fill="#f2d27e"/><circle cx="78" cy="79" r="25" fill="#f8e9be" stroke="none"/>
    ${Array.from({length:8},(_,i)=>`<path d="M78 79 81 57Q91 58 96 65Z" fill="#e79783" stroke="#fff1d2" stroke-width="2" transform="rotate(${i*45} 78 79)"/>`).join('')}`,
  pretzel: `${shadow}
    <path d="M38 91Q13 67 23 43Q32 27 48 41L89 92Q99 97 105 83Q115 61 96 43Q82 29 71 44L26 91Q21 99 31 103Q60 114 91 101" stroke="#a87750" stroke-width="18"/>
    <path d="M38 91Q13 67 23 43Q32 27 48 41L89 92Q99 97 105 83Q115 61 96 43Q82 29 71 44L26 91Q21 99 31 103Q60 114 91 101" stroke="#e6b575" stroke-width="12"/>
    <path d="M25 55 29 57 M36 40 39 43 M53 54 55 58 M73 80 77 81 M101 66 104 69 M81 44 84 41 M51 99 55 102 M74 103 79 102" stroke="#fff2d6" stroke-width="3"/>`,
  glacier: `
    <path d="M10 82 24 42 48 17 63 42 83 25 109 77V100L84 108 40 102Z" fill="#a8d3e5"/>
    <path d="M11 82 48 17 45 68 37 91 41 102 M48 17 63 42 58 72 73 105 M83 25 87 70 109 77" fill="#dceff0"/>
    <path d="M16 101Q35 93 51 103Q74 94 105 106" stroke="#7eaccc" stroke-width="5"/>
    <path d="M36 49 30 70 M71 55 72 72 M91 76 97 88" stroke="#80b5d0" stroke-width="3"/>`,
  peninsula: `
    <path d="M10 25H110V102Q82 111 59 103Q32 111 10 99Z" fill="#a2d5e6" stroke="none"/>
    <path d="M11 25H65L64 47Q51 63 77 72Q95 80 85 92Q75 100 59 90Q35 80 38 59L28 51H11Z" fill="#ecd49b"/>
    <path d="M11 27H60L58 45Q44 65 70 78Q88 86 78 90Q54 85 47 71Q36 48 26 46H11Z" fill="#9bc488" stroke="none"/>
    <path d="M78 51H101 M89 67H106 M19 86H31 M39 100H47" stroke="#def1ee" stroke-width="3"/>
    <path d="M29 28 21 40H37Z" fill="#6e9d6f" stroke-width="2"/>`,
  canyon: `
    <path d="M11 38 39 22 50 35 37 60 49 72 33 107H11Z" fill="#d1a07b"/>
    <path d="M109 29 83 23 69 40 80 58 64 76 78 109H109Z" fill="#c78f70"/>
    <path d="M11 50 40 42 M11 68 35 62 M11 90 37 82 M78 48 109 45 M74 69 109 65 M75 91 109 89" stroke="#ebc49a" stroke-width="5"/>
    <path d="M61 34Q47 52 57 69Q65 83 48 109H73Q84 86 69 72Q55 54 66 35Z" fill="#a5d5df" stroke="none"/>`,
  geyser: `
    <ellipse cx="60" cy="101" rx="47" ry="10" fill="#ccbfa5"/>
    <ellipse cx="60" cy="98" rx="27" ry="6" fill="#8bb9cd"/>
    <path d="M44 96Q55 60 47 40Q30 32 29 19Q38 12 46 30Q43 9 57 11Q66 11 63 31Q79 13 88 24Q91 32 71 40Q65 62 77 96Z" fill="#b2dfe8"/>
    <path d="M58 91V48 M65 32 75 25 M46 38 38 27" stroke="#edf7f1" stroke-width="4"/>
    ${dots([[25,45],[91,46],[36,58],[84,65],[27,76]], '#a6d8e5', 3)}`,
  avalanche: `
    <path d="M9 102 50 17Q57 8 64 20L110 103Z" fill="#94adbf"/>
    <path d="M36 44 50 17Q57 8 64 20L78 46 64 38 53 49 46 38Z" fill="#f5f6e9"/>
    <path d="M57 37 79 61 66 61 91 87 74 83" stroke="#dce6e8" stroke-width="12"/>
    <path d="M34 101Q20 96 29 86Q28 73 43 74Q44 62 58 66Q74 56 81 72Q96 69 98 83Q112 85 107 102Z" fill="#f5f6ec"/>
    <path d="M39 84Q45 78 51 85 M70 82Q79 75 86 83 M55 98Q61 89 69 96" stroke="#bbd1df" stroke-width="2.5"/>`,
  stalactite: `
    <path d="M10 15H110V34L95 30 83 40 68 29 50 37 31 29 10 39Z" fill="#c6af92"/>
    <path d="M18 33 27 85 38 31Z M48 34 60 109 74 31Z M84 37 95 83 104 33Z" fill="#d9c5a6"/>
    <path d="M25 37 28 64 M57 39 61 86 M94 39 95 64" stroke="#f1e1c6" stroke-width="3"/>
    <path d="M10 20 28 25 43 21 64 24 83 19 110 24" stroke="#a68d72" stroke-width="3"/>`,
  crystal: `${shadow}
    <path d="M42 44 58 12 75 41 70 98 53 108 41 96Z" fill="#bba4d9"/>
    <path d="M58 12 57 42 53 108 M42 44 57 42 75 41" fill="#e0ceed"/>
    <path d="M14 63 24 46 41 61 51 103 33 103Z" fill="#a1c6dd"/>
    <path d="M24 46 29 65 33 103 M14 63 29 65 41 61" fill="#d2e4eb"/>
    <path d="M74 62 92 41 108 60 93 99 70 105Z" fill="#9dc8c7"/>
    <path d="M92 41 90 66 70 105 M74 62 90 66 108 60" fill="#cde7de"/>
    ${stars}`,
  fossil: `${shadow}
    <path d="M30 20 75 17 105 39 110 81 85 107 37 103 12 77 16 41Z" fill="#d5c5a6"/>
    <path d="M40 84Q11 63 35 39Q59 17 83 44Q104 72 75 86Q47 99 40 74Q33 54 55 47Q73 41 80 60Q87 76 68 81Q53 87 50 71Q47 58 62 56Q72 55 72 66Q72 75 63 72" stroke="#9f8b6e" stroke-width="5"/>
    <path d="M29 48 38 52 M29 65 39 64 M41 34 47 43 M58 28 59 41 M78 35 73 44 M93 52 83 57 M91 74 81 70 M78 89 75 80 M59 92 61 83" stroke="#a28e70" stroke-width="2.5"/>
    <path d="M18 78 25 81 M94 30 91 38 M87 99 97 88" stroke="#eee0c2"/>`,
  nebula: `
    <path d="M17 70Q5 51 25 39Q20 18 43 22Q63 6 74 29Q100 18 102 47Q117 64 97 77Q99 102 74 97Q56 117 44 94Q19 105 17 70Z" fill="#d5b8df" stroke="none"/>
    <path d="M23 66Q22 35 48 42Q67 18 81 42Q106 52 83 70Q77 101 52 85Q29 90 23 66Z" fill="#bdaedb" stroke="none"/>
    <path d="M37 68Q37 48 59 51Q76 35 84 54Q88 74 65 75Q53 92 43 77Z" fill="#e8cce5" stroke="none"/>
    <path d="M58 43 61 57 74 61 61 65 58 79 54 65 42 61 54 57Z" fill="#fff5d6" stroke="none"/>
    ${stars}${dots([[35,34],[92,57],[31,82],[79,93]], '#fff5df', 2)}`,
  supernova: `
    <circle cx="60" cy="61" r="38" fill="#efd0b1" stroke="none"/>
    <path d="M60 10 68 43 99 22 79 51 111 62 77 70 98 100 68 81 59 113 51 81 21 102 42 70 10 61 43 51 22 21 52 43Z" fill="#f3cc80"/>
    <path d="M60 32 66 51 84 61 66 70 60 91 52 71 34 61 52 52Z" fill="#fff2cb" stroke="none"/>
    <circle cx="60" cy="61" r="10" fill="#fffbee" stroke="none"/>${stars}`,
  eclipse: `
    <circle cx="61" cy="61" r="45" fill="#f4dc9b" stroke="none"/>
    <path d="M61 10V18 M61 103V112 M10 61H18 M103 61H112 M25 25 31 31 M91 91 97 97 M25 97 31 91 M91 31 97 25" stroke="#e0ba72" stroke-width="3"/>
    <circle cx="61" cy="61" r="34" fill="#53647f" stroke="#edd18c" stroke-width="3"/>
    <circle cx="46" cy="51" r="8" fill="#61718a" stroke="none"/>
    <circle cx="72" cy="75" r="11" fill="#5d6d87" stroke="none"/>
    <path d="M85 31 88 38 96 40 88 43 85 50 82 42 75 40 82 38Z" fill="#fff6d7" stroke="none"/>`,
  universe: `
    <circle cx="60" cy="60" r="49" fill="#6e779b" stroke="none"/>
    <path d="M30 51Q49 24 71 44Q87 60 71 73Q58 84 48 73Q38 62 53 55Q64 50 66 61Q68 70 59 68 M90 70Q69 100 44 81" stroke="#c6b6df" stroke-width="7"/>
    <circle cx="28" cy="84" r="9" fill="#8dc4c7" stroke-width="2"/>
    <ellipse cx="89" cy="35" rx="17" ry="5" transform="rotate(-26 89 35)" stroke="#e3c285" stroke-width="3"/>
    <circle cx="89" cy="35" r="8" fill="#e2b882" stroke-width="2"/>
    ${dots([[33,31],[52,21],[93,73],[76,96],[19,57],[68,38],[41,99]], '#fff0c7', 2)}`,
  capsule: `${shadow}
    <path d="M32 82 39 47 53 21H69L84 46 92 82Z" fill="#e9e2cb"/>
    <path d="M53 21V13H69V21 M31 82H94V94Q60 108 27 94Z" fill="#a2b4c4"/>
    <path d="M44 48H77L80 75H41Z" fill="#afcddd"/>
    <circle cx="61" cy="58" r="11" fill="#6b94ad" stroke="#f3ebd5" stroke-width="3"/>
    <path d="M42 86H81 M50 33H73" stroke="#b4b9bc"/>
    ${stars}`,
  spacesuit: `${shadow}
    <path d="M37 50 19 60 14 83 28 88 40 68 41 90 38 109H54L60 88 66 109H83L78 86 78 67 91 84 106 76 96 56 80 48Z" fill="#ede9dc"/>
    <rect x="41" y="46" width="38" height="42" rx="10" fill="#f6efde"/>
    <circle cx="60" cy="31" r="22" fill="#e9e5d7"/>
    <rect x="44" y="20" width="32" height="23" rx="10" fill="#a7c3d2"/>
    <path d="M50 24H58" stroke="#edf7f0" stroke-width="3"/>
    <rect x="48" y="58" width="24" height="17" rx="3" fill="#a7bbc8"/>
    ${dots([[54,64],[64,64]], '#e4aa7e', 2.5)}
    <path d="M39 101H55 M67 101H82 M17 78 30 83 M91 78 103 72" stroke="#a9bbc5" stroke-width="5"/>`,
  accordion: `${shadow}
    <path d="M32 35Q60 10 88 34" stroke="#a3836e" stroke-width="5"/>
    <rect x="12" y="31" width="24" height="66" rx="6" fill="#b5899d"/>
    <path d="M36 36 42 31 49 37 55 31 62 37 69 31 76 36 83 31 88 36V94L82 99 76 94 69 100 62 94 55 100 49 94 42 100 36 94Z" fill="#dac7b9"/>
    <path d="M42 35V94 M49 38V93 M55 35V94 M62 38V93 M69 35V94 M76 38V93 M83 35V94" stroke="#a88278" stroke-width="2"/>
    <rect x="87" y="31" width="22" height="68" rx="5" fill="#b5899d"/>
    <path d="M20 41H31V86H20Z" fill="#fff3d8"/>
    <path d="M20 50H29 M20 60H29 M20 70H29 M20 80H29" stroke-width="3"/>
    ${dots([[97,43],[101,53],[96,63],[101,73],[96,83]], '#f4dec3', 2.5)}`,
  clarinet: `${shadow}
    <path d="M55 14H64L68 75 81 103Q63 112 39 103L51 75Z" fill="#5d6f7c"/>
    <path d="M55 13 58 7H64V21H55Z" fill="#b3b7b9"/>
    <path d="M54 29H65 M53 48H67 M51 72H68 M44 95H76" stroke="#d0c7b4" stroke-width="4"/>
    <path d="M61 35V87" stroke="#c9c7ba" stroke-width="2.5"/>
    ${[[58,39],[65,44],[57,57],[64,62],[58,79],[66,86]].map(([x,y])=>`<circle cx="${x}" cy="${y}" r="3" fill="#d7d0ba" stroke-width="1.5"/>`).join('')}
    <ellipse cx="60" cy="103" rx="20" ry="5" fill="#4d5a69"/>`,
  trombone: `${shadow}
    <path d="M32 45H90Q108 45 108 62Q108 79 90 79H26" stroke="#b08b59" stroke-width="11"/>
    <path d="M32 45H90Q108 45 108 62Q108 79 90 79H26" stroke="#e9c37e" stroke-width="6"/>
    <path d="M17 27Q35 38 52 40V51Q33 52 17 63Z" fill="#edc57b"/>
    <ellipse cx="17" cy="45" rx="7" ry="18" fill="#c99963"/>
    <path d="M49 54V77 M71 48V76 M27 79V93H16" stroke="#d7b176" stroke-width="4"/>
    <path d="M16 89V97" stroke-width="4"/>`,
  tambourine: `${shadow}
    <ellipse cx="60" cy="63" rx="45" ry="37" fill="#d8a679"/>
    <ellipse cx="60" cy="57" rx="44" ry="34" fill="#f0dfb8"/>
    <ellipse cx="60" cy="57" rx="34" ry="25" fill="#f7ebcd" stroke="#c7a37c" stroke-width="2"/>
    ${[[23,45],[60,25],[98,46],[86,83],[35,83]].map(([x,y])=>`<ellipse cx="${x}" cy="${y}" rx="9" ry="5" fill="#b5b8bd" stroke-width="2"/><ellipse cx="${x}" cy="${y+5}" rx="9" ry="5" fill="#d9d9cf" stroke-width="2"/>`).join('')}
    <path d="M28 18 23 12 M95 19 101 13" stroke="#d9ba80"/>`,
  metronome: `${shadow}
    <path d="M41 16H77L97 104H21Z" fill="#be9573"/>
    <path d="M46 23H71L86 93H32Z" fill="#ecdcba"/>
    <path d="M56 31H63 M53 43H66 M50 55H69 M48 67H72" stroke="#a48c6f" stroke-width="2"/>
    <path d="M60 91 80 28" stroke="#7d8f98" stroke-width="4"/>
    <path d="M68 44 80 48 76 61 64 57Z" fill="#a7bdc2"/>
    <circle cx="60" cy="90" r="6" fill="#b68b64"/>
    <path d="M48 107H70" stroke-width="5"/>`,
  harmonica: `${shadow}
    <path d="M14 51 96 32 108 44V75L27 96 14 85Z" fill="#a6b6c1"/>
    <path d="M14 51 27 62 108 44 M27 62V96" fill="#d8ded9"/>
    <path d="M29 67 103 49V71L29 90Z" fill="#bea07b"/>
    ${Array.from({length:8},(_,i)=>`<path d="M${33+i*9} ${69-i*2.2}v11l5-1.3v-11Z" fill="#6b6c73" stroke-width="1.3"/>`).join('')}
    <path d="M26 46 91 32 M35 59 91 45" stroke="#f1ecdb" stroke-width="3"/>`,
  anemone: `${shadow}
    <path d="M29 93Q22 77 38 64H83Q101 80 92 99Z" fill="#d99ba7"/>
    <path d="M38 76Q15 60 23 35 M45 73Q30 45 43 19 M53 70Q51 37 60 17 M61 71Q75 37 71 22 M71 74Q94 47 89 32 M79 82Q106 71 103 48" stroke="#d7a0bc" stroke-width="8"/>
    <path d="M42 80Q20 80 16 60 M77 89Q101 86 106 74 M49 79Q40 55 50 40 M64 81Q61 59 77 49" stroke="#eab1c1" stroke-width="7"/>
    <ellipse cx="59" cy="81" rx="12" ry="8" fill="#ad7e9b" stroke-width="2"/>`,
  nautilus: `${shadow}
    <path d="M70 79Q94 55 104 68 M74 84Q111 72 109 89 M77 89Q105 87 106 102 M72 94Q91 101 92 109" stroke="#c89a80" stroke-width="5"/>
    <path d="M83 75Q86 40 55 25Q22 16 12 48Q2 81 39 97Q66 111 83 75Z" fill="#edd6b7"/>
    <path d="M77 67Q84 42 62 35Q30 23 24 50Q18 73 46 81Q67 87 72 66Q78 49 59 46Q42 43 40 58Q38 70 53 70Q63 69 59 60" stroke="#b88868" stroke-width="4"/>
    <path d="M24 33 32 42 M14 51 25 54 M17 72 30 67 M34 91 41 79 M57 99 59 84 M76 88 66 80" stroke="#c29978" stroke-width="5"/>
    ${eye(83,81)}`,
  plankton: `
    <circle cx="60" cy="60" r="49" fill="#deedf0" stroke="#a5cbd6" stroke-width="2"/>
    <path d="M59 22 62 39 M32 38 43 47 M21 62 39 62 M33 88 46 76 M66 103 64 82 M92 79 79 71 M103 48 81 53 M85 24 75 41" stroke="#9bbdad" stroke-width="2.5"/>
    <path d="M43 40Q62 31 77 44Q89 60 73 77Q54 92 41 73Q30 56 43 40Z" fill="#b8d59d"/>
    <ellipse cx="58" cy="59" rx="11" ry="16" transform="rotate(30 58 59)" fill="#9cb6cb" stroke-width="2"/>
    ${dots([[44,53],[67,47],[71,67],[51,76],[36,28],[92,94],[24,79]], '#89bda6', 3)}`,
  stingray: `${shadow}
    <path d="M60 70Q79 85 88 98Q100 106 106 94" stroke="#829ca9" stroke-width="5"/>
    <path d="M60 23Q74 48 108 56Q98 68 80 79L60 69 41 82Q20 67 12 57Q43 48 60 23Z" fill="#a1bfca"/>
    <path d="M61 29 61 66 M20 58Q42 57 47 71 M102 57Q80 58 73 72" stroke="#c8dbe0" stroke-width="3"/>
    ${eye(51,51)}${eye(68,51)}
    <path d="M54 62Q59 66 65 61" stroke-width="2"/>`,
  swordfish: `${shadow}
    <path d="M21 64 11 42 14 83 28 72Q50 96 79 70L112 55 78 58Q55 36 24 56Z" fill="#97bbce"/>
    <path d="M40 48 49 25 62 47 M43 81 53 96 62 79" fill="#779caf"/>
    <path d="M27 68Q50 81 72 67" fill="#d5e5e6" stroke="none"/>
    <path d="M56 59Q49 67 57 75 M61 69 53 85 71 73" fill="#8eafbf" stroke-width="2"/>
    ${eye(71,60)}`,
  microscope: `${shadow}
    <path d="M47 31 60 45 86 18 74 9Z" fill="#9ab3bf"/>
    <path d="M69 16 81 29 M44 34 56 46 47 57 35 46Z" fill="#bfd0d4"/>
    <path d="M70 35Q101 43 91 74Q84 91 63 95" stroke="#89a7b5" stroke-width="12"/>
    <path d="M31 66H75V73H31Z M55 73V98 M30 107H96L86 96H43Z" fill="#b5c9cc"/>
    <circle cx="83" cy="51" r="8" fill="#dcbf8d"/>
    <path d="M39 62H61 M44 84 57 80 64 86" stroke="#d4bc8c" stroke-width="3"/>`,
  compass: `${shadow}
    <circle cx="60" cy="17" r="8" fill="#e3c392"/>
    <circle cx="60" cy="66" r="42" fill="#dec38f"/><circle cx="60" cy="66" r="34" fill="#fff0d0"/>
    <path d="M60 33V41 M60 91V99 M27 66H35 M86 66H93 M37 43 42 48 M78 84 83 89 M36 90 42 84 M78 48 84 42" stroke="#b39c7e" stroke-width="2.5"/>
    <path d="M76 39 63 70 45 92 55 61Z" fill="#8eadbb"/>
    <path d="M76 39 63 70 55 61Z" fill="#cf8580"/>
    <circle cx="60" cy="66" r="4" fill="#ecd8ae"/>`,
  hourglass: `${shadow}
    <path d="M32 22H88Q90 46 67 60Q91 77 88 101H32Q29 77 53 60Q29 44 32 22Z" fill="#dbecee"/>
    <path d="M36 33H84Q81 47 60 57Q41 47 36 33Z" fill="#e9cc8e" stroke="none"/>
    <path d="M35 96Q42 79 60 79Q78 79 85 96Z" fill="#e7c386" stroke="none"/>
    <path d="M60 59V78" stroke="#e0bb78" stroke-width="3"/>
    <path d="M25 14H96V23H25Z M25 100H96V109H25Z" fill="#bd9673"/>
    <path d="M38 26Q37 37 43 43 M79 78 82 87" stroke="#fff8df" stroke-width="3"/>`,
  binoculars: `${shadow}
    <path d="M29 29H47L54 83H14Z M75 29H93L107 83H66Z" fill="#97b5b3"/>
    <path d="M30 22H46V35H27Z M75 22H92L95 35H75Z" fill="#77908f"/>
    <path d="M48 42H75V68H49Z" fill="#acc5bc"/>
    <circle cx="34" cy="84" r="22" fill="#779493"/><circle cx="87" cy="84" r="22" fill="#779493"/>
    <circle cx="34" cy="84" r="15" fill="#acd4dd"/><circle cx="87" cy="84" r="15" fill="#acd4dd"/>
    <path d="M25 84Q24 77 32 75 M79 84Q79 77 86 75" stroke="#ecf5e8" stroke-width="4"/>
    <rect x="55" y="35" width="13" height="18" rx="4" fill="#c9b891"/>`,
  abacus: `${shadow}
    <path d="M13 20H107V106H13Z M21 28V98H99V28Z" fill="#c9a17a" fill-rule="evenodd"/>
    <path d="M21 42H99 M21 61H99 M21 80H99" stroke="#aa9d85" stroke-width="3"/>
    ${[[31,42,'#e3a282'],[44,42,'#e3a282'],[57,42,'#e3a282'],[86,42,'#e3a282'],[31,61,'#96b8c7'],[71,61,'#96b8c7'],[85,61,'#96b8c7'],[31,80,'#a6be80'],[44,80,'#a6be80'],[58,80,'#a6be80'],[72,80,'#a6be80']].map(([x,y,c])=>`<ellipse cx="${x}" cy="${y}" rx="5" ry="7" fill="${c}" stroke-width="1.8"/>`).join('')}`
};
