// Original, child-readable silhouettes on a 120-pixel canvas.
module.exports = {
  whale: `
    <path d="M18 69 Q12 39 43 38 Q71 36 78 62 Q91 65 97 47 L110 48 Q109 67 98 78 Q81 98 51 93 Q23 90 18 69Z" fill="#85bfda"/>
    <path d="M19 72 Q34 84 58 82 Q80 80 91 73 Q73 100 45 91 Q24 85 19 72Z" fill="#d1eaf1" stroke="none"/>
    <path d="M66 69 Q85 81 67 89 Q56 82 58 72" fill="#69aacb"/>
    <circle cx="33" cy="57" r="3.5" fill="#765445" stroke="none"/>
    <path d="M19 68 Q28 75 37 69 M50 32V22 Q44 13 40 24 M50 22 Q55 12 61 22"/>
    <path d="M22 103H44 M70 103H98" stroke="#a5d8df"/>`,
  shark: `
    <path d="M42 47 59 20 68 46" fill="#8eaebe"/>
    <path d="M16 64 Q40 33 79 53 L105 33 100 62 107 83 79 73 Q43 91 16 64Z" fill="#9abcca"/>
    <path d="M19 66 Q45 68 79 67 Q59 88 27 76Z" fill="#e2ecec" stroke="none"/>
    <path d="M56 70 72 91 70 73" fill="#7f9eaf"/>
    <path d="M22 68 39 68 35 74 30 68 27 73Z" fill="#fff7e6" stroke-width="2"/>
    <circle cx="30" cy="56" r="3" fill="#765445" stroke="none"/>
    <path d="M48 54 44 63 M56 55 52 64 M64 56 60 65" stroke-width="2.5"/>
    <path d="M20 101H45 M79 98H101" stroke="#a5d8df"/>`,
  crab: `
    <path d="M35 71 19 65 11 71 M34 81 18 84 10 95 M42 90 30 100 21 99 M85 71 101 65 109 71 M86 81 102 84 110 95 M78 90 90 100 99 99" stroke="#d98066" stroke-width="6"/>
    <path d="M36 66 24 53 M84 66 96 53" stroke="#e88e74" stroke-width="7"/>
    <path d="M26 56 Q5 49 15 25 L23 39 33 24 Q42 47 26 56Z M94 56 Q115 49 105 25 L97 39 87 24 Q78 47 94 56Z" fill="#ee9a7f"/>
    <ellipse cx="60" cy="76" rx="31" ry="23" fill="#efaa88"/>
    <path d="M48 58 45 44 M72 58 75 44" stroke-width="5"/>
    <circle cx="45" cy="43" r="6" fill="#fff1d5"/><circle cx="75" cy="43" r="6" fill="#fff1d5"/>
    <circle cx="45" cy="43" r="2.5" fill="#765445" stroke="none"/><circle cx="75" cy="43" r="2.5" fill="#765445" stroke="none"/>
    <path d="M51 78 Q60 88 69 78"/>`,
  seal: `
    <ellipse cx="62" cy="103" rx="43" ry="5" fill="#d1e7e7" stroke="none"/>
    <path d="M31 87 Q43 69 51 51 Q57 31 77 35 Q100 40 94 65 L89 83 Q99 78 109 87 L97 99 72 98 Q35 105 22 97 L12 80 26 86Z" fill="#b3c5cc"/>
    <path d="M53 76 Q54 98 73 96 L67 82" fill="#95afb9"/>
    <ellipse cx="74" cy="63" rx="17" ry="13" fill="#e0e7e8" stroke="none"/>
    <circle cx="65" cy="51" r="3" fill="#765445" stroke="none"/><circle cx="87" cy="52" r="3" fill="#765445" stroke="none"/>
    <path d="M70 61 79 61 75 66Z" fill="#765445" stroke="none"/>
    <path d="M75 66 Q69 73 65 67 M75 66 Q80 73 85 67 M62 62 49 59 M62 68 48 70 M87 62 102 60 M87 68 102 72" stroke-width="2"/>`,
  shell: `
    <ellipse cx="59" cy="107" rx="42" ry="4" fill="#eadbc5" stroke="none"/>
    <path d="M74 91 Q54 108 33 94 Q10 78 18 49 Q27 20 57 19 Q86 18 99 46 Q111 77 90 101 L68 100Z" fill="#f3caa5"/>
    <path d="M73 84 Q49 94 35 78 Q22 61 37 44 Q50 29 69 39 Q85 49 75 66 Q65 80 53 69 Q45 60 54 53 Q62 48 66 55" stroke="#c68b69" stroke-width="4"/>
    <path d="M85 57 Q100 68 91 94 L73 100 Q66 82 75 67Z" fill="#eaa49b"/>
    <path d="M84 69 Q93 82 84 94" stroke="#bc7e77" stroke-width="3"/>
    <path d="M28 40 36 47 M39 26 44 38 M57 21 57 33 M77 27 72 39 M21 63 32 62 M29 85 37 78" stroke="#dca47d" stroke-width="2.5"/>
    <path d="M29 36 Q36 28 45 26" stroke="#ffead0" stroke-width="4"/>`,
  coral: `
    <ellipse cx="60" cy="104" rx="39" ry="6" fill="#e5d2b8" stroke="none"/>
    <path d="M53 103V75 Q29 73 25 60 L24 46 12 37 14 29 32 39 33 23 43 23 43 58 54 62 55 25 49 17 54 10 65 18 65 43 76 32 76 15 86 15 86 34 101 27 106 35 86 47 66 62 66 78 83 69 91 51 101 55 94 78 67 91 69 103Z" fill="#eb9e94"/>
    <path d="M59 97V70 M31 44 34 60 M81 47 72 53 M86 77 74 83" stroke="#fbc9b9" stroke-width="3"/>
    <circle cx="27" cy="96" r="5" fill="#a4cab5" stroke="none"/><circle cx="92" cy="97" r="4" fill="#a4cab5" stroke="none"/>`,
  squid: `
    <path d="M45 53 24 72 45 72 M75 53 96 72 75 72" fill="#d0b1d2"/>
    <path d="M44 75 Q38 102 23 99 Q13 96 21 86 M51 76 Q43 111 40 103 M60 77V109 M69 76 Q77 111 80 103 M76 75 Q82 102 97 99 Q107 96 99 86" stroke="#b78dbd" stroke-width="6"/>
    <path d="M43 74 Q39 36 60 13 Q81 36 77 74Z" fill="#d8b9dc"/>
    <path d="M51 42 Q52 32 59 26" stroke="#f1d9ed" stroke-width="4"/>
    <circle cx="50" cy="62" r="5" fill="#fff2dc"/><circle cx="70" cy="62" r="5" fill="#fff2dc"/>
    <circle cx="50" cy="62" r="2" fill="#765445" stroke="none"/><circle cx="70" cy="62" r="2" fill="#765445" stroke="none"/>`,
  clam: `
    <path d="M23 68 Q10 46 25 35 Q34 20 47 28 Q62 17 76 29 Q93 24 100 41 Q112 56 96 71Z" fill="#c7b2d9"/>
    <path d="M28 42 45 64 M44 33 53 60 M61 29V59 M78 35 69 62 M94 46 80 66" stroke="#9f83b8" stroke-width="2.5"/>
    <ellipse cx="60" cy="77" rx="42" ry="20" fill="#f0d4d9"/>
    <ellipse cx="60" cy="76" rx="32" ry="12" fill="#b18ca8" stroke-width="2.5"/>
    <path d="M37 79 Q35 62 51 62 Q61 53 72 64 Q85 66 81 79 Q63 88 37 79Z" fill="#f6ddbb" stroke="#c79587" stroke-width="2.5"/>
    <path d="M43 75 Q57 64 74 73" stroke="#fff0d4" stroke-width="3"/>
    <path d="M18 77 Q27 105 60 107 Q94 103 102 77 Q88 94 60 94 Q32 94 18 77Z" fill="#dac0dc"/>
    <path d="M34 98 39 94 M49 105 51 97 M65 106 64 98 M82 100 77 95" stroke="#af8eaf" stroke-width="2"/>`,
  earth: `
    <circle cx="60" cy="60" r="43" fill="#8dc8e0"/>
    <path d="M30 30 43 24 50 33 46 43 56 51 51 60 42 58 35 67 28 57 20 54 18 46Z M47 65 61 62 72 73 66 86 57 98 52 82 43 76Z M77 22 93 35 97 48 85 51 80 64 71 58 66 47 72 39 68 29Z M85 75 97 79 91 93 80 92 76 83Z" fill="#a9cd8f" stroke-width="2.5"/>
    <path d="M37 22 Q51 13 66 19" stroke="#d5eff3" stroke-width="4"/>
    <path d="M20 82 Q26 93 37 98" stroke="#b8e5ee" stroke-width="3"/>`,
  rocket: `
    <path d="M48 85 Q42 103 53 108 L60 99 68 110 Q80 99 71 85" fill="#efb660"/>
    <path d="M55 87 Q50 102 60 105 Q70 98 66 87" fill="#f8df84" stroke="none"/>
    <path d="M42 60 Q23 69 26 95 L45 83 M78 60 Q97 69 94 95 L75 83" fill="#db9dac"/>
    <path d="M42 83 Q30 40 60 10 Q90 40 78 83Z" fill="#dde6ea"/>
    <path d="M44 31 Q50 19 60 10 Q70 19 76 31Z" fill="#db9dac"/>
    <path d="M42 76H78V87H42Z" fill="#b6a3cf"/>
    <circle cx="60" cy="52" r="13" fill="#9dcbdc"/>
    <path d="M55 47 61 43" stroke="#e8f4ef" stroke-width="4"/>
    <path d="M15 32V40 M11 36H19 M102 47V55 M98 51H106" stroke="#dbc883" stroke-width="2.5"/>`,
  planet: `
    <ellipse cx="60" cy="61" rx="51" ry="16" transform="rotate(-24 60 61)" fill="#e4c586"/>
    <circle cx="60" cy="57" r="32" fill="#d2add7"/>
    <path d="M31 47 Q55 52 82 36 M30 63 Q60 66 90 50 M36 77 Q65 80 90 64" stroke="#b58dbf" stroke-width="5"/>
    <path d="M15 79 Q28 95 70 77 Q110 60 106 42 L111 47 Q115 65 73 84 Q32 102 16 89Z" fill="#edcf8f"/>
    <path d="M20 86 Q40 96 72 82" stroke="#fae9b6" stroke-width="2.5"/>
    <circle cx="21" cy="25" r="3" fill="#dfca8f" stroke="none"/><circle cx="99" cy="96" r="4" fill="#bca3da" stroke="none"/>`,
  comet: `
    <path d="M29 72 Q44 32 104 13 Q83 45 49 79Z" fill="#abd6e8" stroke="#6c9ab7"/>
    <path d="M35 85 Q63 54 111 48 Q79 78 46 92Z" fill="#d6eaf1" stroke="#89b6c9" stroke-width="2.5"/>
    <path d="M43 69 Q65 43 92 29 M51 84 Q75 66 95 61" stroke="#f0faff" stroke-width="4"/>
    <circle cx="32" cy="83" r="21" fill="#cfe9ee" stroke="#6c9ab7"/>
    <circle cx="29" cy="84" r="10" fill="#8eb9c8" stroke="#6c9ab7" stroke-width="2.5"/>
    <path d="M23 76 26 73 M25 87 30 91" stroke="#f8ffff" stroke-width="3"/>
    <path d="M19 29V41 M13 35H25 M94 93V101 M90 97H98" stroke="#b19acb" stroke-width="2.5"/>`,
  meteor: `
    <path d="M14 98 Q62 82 109 101" stroke="#bddde5" stroke-width="7"/>
    <path d="M13 108 Q61 91 109 111" stroke="#e0edf0" stroke-width="4"/>
    <path d="M36 68 Q55 23 102 11 L89 36 109 27 Q85 59 55 87Z" fill="#e99663" stroke="#ba7350"/>
    <path d="M44 70 84 30 71 53 92 43 56 80Z" fill="#f9d477" stroke="none"/>
    <circle cx="37" cy="77" r="23" fill="#f4ba65" stroke="#ba7350"/>
    <path d="M24 73 31 62 43 64 52 77 45 89 29 87Z" fill="#a88b7b"/>
    <path d="M31 69 36 67 M40 80 43 82" stroke="#dcc2a4" stroke-width="3"/>
    <path d="M23 47 32 38 M60 96 74 83" stroke="#e9aa6e" stroke-width="3"/>`,
  alien: `
    <path d="M40 91 Q38 75 47 72 H73 Q82 75 80 91 L96 102 85 109 69 97 H51 L35 109 24 102Z" fill="#b0cdb5"/>
    <path d="M38 37 30 22 M82 37 90 22" stroke="#80aa91" stroke-width="5"/>
    <circle cx="28" cy="18" r="7" fill="#d4dda2"/><circle cx="92" cy="18" r="7" fill="#d4dda2"/>
    <path d="M24 50 Q24 29 60 27 Q96 29 96 50 Q95 68 71 80 Q60 86 49 80 Q25 68 24 50Z" fill="#b7d59c"/>
    <ellipse cx="43" cy="52" rx="9" ry="12" transform="rotate(-25 43 52)" fill="#6b7988"/>
    <ellipse cx="77" cy="52" rx="9" ry="12" transform="rotate(25 77 52)" fill="#6b7988"/>
    <circle cx="42" cy="49" r="3" fill="#f6efd8" stroke="none"/><circle cx="78" cy="49" r="3" fill="#f6efd8" stroke="none"/>
    <path d="M54 69 Q60 74 66 69" stroke-width="2.5"/>`,
  rover: `
    <path d="M13 103 Q55 91 107 104" stroke="#dacfbf" stroke-width="5"/>
    <path d="M34 71 27 87 M86 71 94 87 M58 72V87" stroke="#a29cac" stroke-width="6"/>
    <path d="M26 57 43 43 83 48 96 65 83 82 39 78Z" fill="#dfc286"/>
    <path d="M27 58 80 63 96 65 M80 63 83 82 M44 44 41 60" stroke-width="2.5"/>
    <path d="M66 46V27" stroke="#9dabbc" stroke-width="6"/>
    <rect x="52" y="17" width="30" height="16" rx="5" fill="#b9cbd7"/>
    <circle cx="73" cy="25" r="4" fill="#668d9e"/>
    <path d="M40 45 28 31 28 22 M23 21H33" stroke-width="3"/>
    <circle cx="26" cy="89" r="13" fill="#8b8e9d"/><circle cx="60" cy="94" r="13" fill="#8b8e9d"/><circle cx="94" cy="89" r="13" fill="#8b8e9d"/>
    <circle cx="26" cy="89" r="5" fill="#d4dce1"/><circle cx="60" cy="94" r="5" fill="#d4dce1"/><circle cx="94" cy="89" r="5" fill="#d4dce1"/>`,
  galaxy: `
    <ellipse cx="60" cy="62" rx="45" ry="31" transform="rotate(-22 60 62)" fill="#e0d3ed" stroke="none"/>
    <path d="M58 62 Q68 42 89 46 Q108 51 95 72 Q82 94 48 94 Q23 92 18 79 Q37 87 58 77 Q33 83 28 67 Q21 47 46 31 Q71 13 96 24 Q66 23 54 45 Q41 64 58 62Z" fill="#baa0d5" stroke-width="2.5"/>
    <path d="M55 62 Q65 51 74 58 Q84 69 65 77 M44 45 Q61 28 79 29 M34 83 Q54 89 75 79" stroke="#eee2f6" stroke-width="3"/>
    <ellipse cx="60" cy="62" rx="12" ry="9" transform="rotate(-22 60 62)" fill="#f7d89b"/>
    <circle cx="24" cy="28" r="3" fill="#d5b979" stroke="none"/><circle cx="95" cy="97" r="3" fill="#d5b979" stroke="none"/>
    <path d="M101 20V30 M96 25H106 M19 97V105 M15 101H23" stroke="#b393ca" stroke-width="2.5"/>`
};
