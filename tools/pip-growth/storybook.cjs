'use strict';

// Original Pip illustration, reworked as a warm, articulated storybook character.
// The cheek, crown, wing and webbed-foot contours derive from the project's
// pip.svg / pip-dance-parts.svg. These are authored illustration layers, not
// runtime drawing. Sharp is needed only to export the reviewed PNG artwork.
const fs = require('node:fs');
const path = require('node:path');
const sharp = require(process.env.SHARP_MODULE || 'sharp');
const ROOT = path.resolve(__dirname, '../..');
const OUT = path.join(ROOT, 'build/pip-models');
const AGES = [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
const FACES = ['neutral', 'listening', 'thinking', 'delighted', 'proud', 'encourage', 'surprised', 'sleepy', 'wink', 'blink', 'speaking'];
const PARTS = ['body', 'head', 'left-wing', 'right-wing', 'left-foot', 'right-foot'];
const INK = '#b78642', DARK = '#49372c';
// Head half-width, half-height, center, shoulder, hem, torso half-width.
const FORMS = {
  0: [32, 28, 49, 75, 105, 24], 3: [31, 27, 44, 70, 103, 23],
  4: [29.5, 26, 42, 67, 101, 23], 5: [28.5, 25.5, 41, 66, 100, 24],
  6: [28, 25, 40, 64, 100, 23], 7: [27, 24, 39, 62, 99, 23],
  8: [27, 24, 38, 61, 100, 24], 9: [26, 23, 38, 61, 99, 23],
  10: [26, 23, 37, 60, 99, 22], 11: [25.5, 22.5, 37, 59, 99, 23],
  12: [25.5, 22.5, 36, 58, 99, 23],
};
const COLORS = {
  0: ['#f7efd6','#e5d9bd'], 3: ['#9bcfc0','#77b6a7'],
  4: ['#8fbccc','#709eb7'], 5: ['#efbc76','#d49b59'],
  6: ['#df9b91','#c77f76'], 7: ['#a6be91','#839f71'],
  8: ['#c5afd3','#ac90bc'], 9: ['#8dafc2','#6d93aa'],
  10: ['#94b5cb','#7699b4'], 11: ['#cf9d88','#b58070'],
  12: ['#91bdb2','#709e95'],
};
const p = (d, fill, stroke = 'none', width = 1, extra = '') => `<path d="${d}" fill="${fill}" stroke="${stroke}" stroke-width="${width}" ${extra}/>`;
const e = (cx, cy, rx, ry, fill, extra = '') => `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="${fill}" ${extra}/>`;
const line = (d, color = INK, width = 1, extra = '') => p(d, 'none', color, width, extra);
const group = (content, transform = '', extra = '') => `<g${transform ? ` transform="${transform}"` : ''} ${extra}>${content}</g>`;
function defs(age) {
  const [cloth, fold] = COLORS[age];
  return `<defs>
    <radialGradient id="down" cx=".26" cy=".18" r=".96"><stop stop-color="#fff1b3"/><stop offset=".47" stop-color="#f8d87c"/><stop offset=".82" stop-color="#e7b450"/><stop offset="1" stop-color="#ca913b"/></radialGradient>
    <radialGradient id="down-right" cx=".74" cy=".18" r=".96"><stop stop-color="#fff1b3"/><stop offset=".47" stop-color="#f8d87c"/><stop offset=".82" stop-color="#e7b450"/><stop offset="1" stop-color="#ca913b"/></radialGradient>
    <radialGradient id="face" cx=".32" cy=".24" r=".82"><stop stop-color="#fff5c8"/><stop offset=".42" stop-color="#ffe39a"/><stop offset=".73" stop-color="#f4ca69"/><stop offset="1" stop-color="#d99c40"/></radialGradient>
    <radialGradient id="muzzle" cx=".44" cy=".48" r=".55"><stop stop-color="#fff4ce" stop-opacity=".82"/><stop offset=".54" stop-color="#ffe8aa" stop-opacity=".46"/><stop offset="1" stop-color="#f5cf7e" stop-opacity="0"/></radialGradient>
    <radialGradient id="blush"><stop stop-color="#e99273" stop-opacity=".54"/><stop offset=".55" stop-color="#eeac82" stop-opacity=".28"/><stop offset="1" stop-color="#efbd83" stop-opacity="0"/></radialGradient>
    <radialGradient id="bill" cx=".33" cy=".18" r=".9"><stop stop-color="#ffd399"/><stop offset=".45" stop-color="#f4b267"/><stop offset=".78" stop-color="#e88d43"/><stop offset="1" stop-color="#c76b31"/></radialGradient>
    <linearGradient id="bill-lower" x1="0" y1="0" x2=".2" y2="1"><stop stop-color="#cc763a"/><stop offset=".5" stop-color="#eea35c"/><stop offset="1" stop-color="#d9813e"/></linearGradient>
    <radialGradient id="eye" cx=".35" cy=".22" r=".85"><stop stop-color="#71523c"/><stop offset=".55" stop-color="#403129"/><stop offset="1" stop-color="#2e2926"/></radialGradient>
    <radialGradient id="cloth" cx=".27" cy=".24" r=".88"><stop stop-color="${cloth}"/><stop offset=".42" stop-color="${cloth}"/><stop offset="1" stop-color="${fold}"/></radialGradient>
    <linearGradient id="form-shade" x1="0" y1="0" x2="1" y2=".35"><stop stop-color="#765837" stop-opacity=".12"/><stop offset=".3" stop-color="#765837" stop-opacity="0"/><stop offset=".68" stop-color="#765837" stop-opacity="0"/><stop offset="1" stop-color="#765837" stop-opacity=".22"/></linearGradient>
    <linearGradient id="chin-shade" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#9c6b32" stop-opacity=".28"/><stop offset="1" stop-color="#9c6b32" stop-opacity="0"/></linearGradient>
    <radialGradient id="shell" cx=".31" cy=".18" r=".9"><stop stop-color="#fffdf1"/><stop offset=".45" stop-color="#f4ecd6"/><stop offset=".78" stop-color="#e1d2ae"/><stop offset="1" stop-color="#c9b68c"/></radialGradient>
    <radialGradient id="ground"><stop stop-color="#766449" stop-opacity=".24"/><stop offset=".5" stop-color="#766449" stop-opacity=".12"/><stop offset="1" stop-color="#766449" stop-opacity="0"/></radialGradient>
    <filter id="paper" x="-2%" y="-2%" width="104%" height="104%" color-interpolation-filters="sRGB">
      <feTurbulence type="fractalNoise" baseFrequency="1.1" numOctaves="3" seed="19" result="grain"/>
      <feColorMatrix in="grain" type="saturate" values="0"/>
      <feComponentTransfer><feFuncA type="linear" slope=".065"/></feComponentTransfer>
      <feComposite operator="in" in2="SourceGraphic"/>
      <feBlend in="SourceGraphic" mode="soft-light"/>
    </filter>
  </defs>`;
}
function svg(age, content, pixels = 360) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${pixels}" height="${pixels}" viewBox="0 0 120 120"><title>Pip, a warm storybook duck; ${age ? `age ${age}` : 'Baby'}</title>${defs(age)}<g stroke="none" stroke-linecap="round" stroke-linejoin="round" filter="url(#paper)">${content}</g></svg>`;
}
function head(age, expression = 'neutral') {
  const [hw, hh, cy] = FORMS[age];
  // The original Pip head contour is redrawn with a fuller cheek and a softer
  // chin; a local 64 x 56 face frame keeps every expression exactly registered.
  let behind = '', front = '';
  const top = cy - hh, bottom = cy + hh;
  if (age === 5 || age === 8) {
    behind = p(`M${60-hw-2} ${bottom-7} C${60-hw-12} ${cy+7} ${60-hw-8} ${top-4} 60 ${top-5} C${60+hw+8} ${top-4} ${60+hw+12} ${cy+7} ${60+hw+2} ${bottom-7} Q60 ${bottom+3} ${60-hw-2} ${bottom-7}Z`, 'url(#cloth)', COLORS[age][1], 1.2);
    behind += line(`M${60-hw-4} ${cy+9} Q${60-hw-8} ${top+2} 58 ${top-2}`, '#fff3da', .9, 'opacity=".6"');
  }
  // Broad cheek and forehead planes carry the volume at small header sizes.
  // The lower cheek feathers interrupt the contour without a furry/noisy edge.
  let face = p('M-29-10 C-28-22-18-28-5-27 C8-30 23-26 28-15 C31-9 31-3 31 2 Q31 6 32.5 8 Q33.5 10 31 10 Q33 14 30 16 C28 23 18 28 5 29 C-9 30-22 25-28 20 Q-32 16-31 12 Q-34 11-32 8 C-34 1-32-6-29-10Z', 'url(#face)', INK, .62);
  face += p('M-29 8 Q-30 22-14 26 Q3 33 20 25 Q30 20 31 11 C27 22 14 24 2 24 C-12 25-23 20-29 8Z', '#c58d40', 'none', 0, 'opacity=".15"');
  // Downy crown: one soft hook for Baby, an eager double curl for the youngest,
  // then a calm side-sweep. No hard spikes or extruded hair blades.
  if (age === 0) face += p('M-9-26 C-12-29-11-36-6-35 C-3-33-6-30-4-27 Q0-33 4-30 Q7-27 4-26Z', 'url(#down)', INK, .85);
  else if (age <= 4) face += p('M-9-26 Q-17-34-10-35 Q-4-35-4-28 Q1-36 5-32 Q9-29 7-26Z', 'url(#down)', INK, .85);
  else if (![5, 8, 10].includes(age)) face += p('M-13-25 C-12-29-8-34-2-33 Q1-33-1-31 Q-4-28-2-27 C3-30 9-32 12-29 Q13-28 10-27 L7-25Z', 'url(#down)', INK, .65);
  face += p('M-25-11 C-21-23-7-27 8-23 C-4-24-16-18-22-7 Q-25-3-25-11Z', '#fff9db', 'none', 0, 'opacity=".16"');
  face += p('M-22 5 C-18-1-7 0 0 3 C9-1 19 2 23 9 C26 20 12 25 0 24 C-15 24-27 17-22 5Z', 'url(#muzzle)');
  face += e(-21, 10, 8, 5.5, 'url(#blush)') + e(21, 10.5, 7.5, 5.2, 'url(#blush)');
  const closed = ['blink','sleepy','delighted'].includes(expression);
  const eyeY = age <= 3 ? 0 : -1;
  const eyeX = age <= 3 ? 11.2 : 11;
  const eyeH = age <= 3 ? 6.1 : 5.6;
  for (const side of [-1, 1]) {
    const x = side * eyeX, y = eyeY + (expression === 'surprised' ? -1 : 0);
    if (closed || (expression === 'wink' && side === 1)) {
      const arc = ['delighted','wink'].includes(expression) ? -4.3 : expression === 'sleepy' ? 3 : 1.8;
      face += line(`M${x-4.2} ${y+1} Q${x} ${y+arc} ${x+4.2} ${y+.6}`, DARK, 1.6);
    } else {
      const dx = expression === 'thinking' ? 1.4 : expression === 'listening' ? .8 : 0;
      const h = expression === 'proud' ? eyeH*.85 : expression === 'surprised' ? eyeH*1.12 : eyeH;
      face += p(`M${x+dx-4.1} ${y-1} C${x+dx-4} ${y-h-1.5} ${x+dx+3.7} ${y-h-1.6} ${x+dx+4.1} ${y-1.3} C${x+dx+4.7} ${y+h+.6} ${x+dx-4.6} ${y+h+1.3} ${x+dx-4.1} ${y-1}Z`, 'url(#eye)');
      face += line(`M${x+dx-3.2} ${y+h*.65} Q${x+dx} ${y+h+1} ${x+dx+2.9} ${y+h*.55}`, '#ae7e50', .65, 'opacity=".66"');
      face += e(x+dx-1.2, y-2.7, 1.25, 1.6, '#fff9e9', 'transform="rotate(20 '+(x+dx-1.2)+' '+(y-2.7)+')"');
      face += e(x+dx+1.45, y+1.4, .48, .62, '#f2d3a2', 'opacity=".7"');
    }
    if (['thinking','surprised','listening','encourage'].includes(expression)) {
      const lift = expression === 'thinking' && side === -1 ? -3 : 0;
      face += line(`M${x-3.7} ${y-9+lift} Q${x} ${y-10.3+lift} ${x+3.3} ${y-9.2+lift}`, INK, .8, 'opacity=".72"');
    }
  }
  const open = ['speaking','surprised','delighted'].includes(expression);
  // A connected lower bill and hinge replace the old oval with a hanging mouth.
  face += p('M-11 13 Q0 9 11 13 C10 20-8 21-11 13Z', '#b58140', 'none', 0, 'opacity=".13"');
  if (open) {
    const gap = expression === 'surprised' ? 22 : expression === 'delighted' ? 21 : 20;
    face += p(`M-10 11 Q0 9 10 11 C10 ${gap} 4 ${gap+1} 0 ${gap+1} C-6 ${gap+1}-10 ${gap-2}-10 11Z`, '#85502f', '#bc783b', .55);
    face += p(`M-5 ${gap-3} Q0 ${gap-6} 5 ${gap-3} Q4 ${gap+1} 0 ${gap} Q-4 ${gap+1}-5 ${gap-3}Z`, '#e9a48a');
    face += p(`M-9 ${gap-4} Q0 ${gap+3} 9 ${gap-4} Q8 ${gap+2} 0 ${gap+2} Q-8 ${gap+1}-9 ${gap-4}Z`, 'url(#bill-lower)', '#bd7a3b', .5);
  } else {
    face += p('M-11 11 C-10 19 10 19 12 11 Q1 7-11 11Z', 'url(#bill-lower)', '#c4813f', .6);
  }
  face += p('M-12 10 C-11 7-7 7-4 5.8 Q0 4.2 4 5.8 C7 6.8 12 6.8 13 9.5 C15 13 8 15.3 1 15.5 C-6 15.8-14 14-12 10Z', 'url(#bill)', '#c58b46', .55);
  face += p('M-9 9 C-7 7.8-4 8-1 7 Q3 6.3 7 8 C1 7.6-3 10-9 9Z', '#ffe2b0', 'none', 0, 'opacity=".65"');
  face += line('M-10 12.4 Q0 16.2 11 11.5', '#ad672f', .65, 'opacity=".75"');
  face += e(-3.6,8.3,.65,.4,'#bc8243','opacity=".6"') + e(4.3,8.1,.6,.38,'#bc8243','opacity=".6"');
  face += line('M-27 12 q1 1.7 2.6 2 M25 14 q-1 1.5-2.4 1.8', '#cf9b53', .65, 'opacity=".6"');
  face = group(face, `translate(60 ${cy}) scale(${hw/32} ${hh/28})`);
  if (age === 4) {
    front += p(`M${60-hw*.92} ${top+9} Q60 ${top+2} ${60+hw*.88} ${top+9} L${60+hw*.92} ${top+12} Q60 ${top+8} ${60-hw*.91} ${top+12}Z`, '#91b9c8', '#6e9eaf', .75);
    front += p(`M${60-hw*.96} ${top+11} Q60 ${top+7} ${60+hw*.95} ${top+12} Q${60+hw+7} ${top+16} ${60+hw*.67} ${top+17} Q60 ${top+15} ${60-hw*.96} ${top+14}Z`, '#b5d1d5', '#80a8b6', .8);
  } else if (age === 7) {
    front += p(`M${60-hw*.92} ${top+9} Q60 ${top+4} ${60+hw*.92} ${top+9} L${60+hw*.94} ${top+12} Q60 ${top+8} ${60-hw*.94} ${top+12}Z`, '#f8f0da', '#cebf92', .7);
    front += line(`M${60+hw-2} ${top+11} q7 2 6 7`, '#f8f0da', 3);
  } else if (age === 9) {
    const ey = cy-hh/28;
    for (const side of [-1,1]) front += e(60+side*hw*11/32, ey, 7.3, 7.4, 'none', 'stroke="#688f9c" stroke-width="1.2"');
    front += line(`M57 ${ey} Q60 ${ey-2} 63 ${ey}`, '#688f9c', 1.1);
    front += line(`M${60-hw*.68} ${ey-2} l-4-1 M${60+hw*.68} ${ey-2} l4-1`, '#688f9c', 1.1);
  } else if (age === 10) {
    front += p(`M${60-hw*.96} ${top+10} Q${60-hw} ${top-5} 61 ${top-5} Q${60+hw} ${top-3} ${60+hw*.95} ${top+11} Q60 ${top+5} ${60-hw*.96} ${top+10}Z`, 'url(#cloth)', '#7298b0', 1);
    front += p(`M${60+hw*.6} ${top+8} Q${60+hw+14} ${top+7} ${60+hw+10} ${top+12} Q${60+hw+5} ${top+15} ${60+hw*.7} ${top+12}Z`, '#9ab6c9', '#7298b0', .9);
    front += line(`M59 ${top-3} Q66 ${top+2} 63 ${top+8}`, '#d3e1e5', .8);
    front += p(`M${60-hw*.65} ${top+6} q5-5 10-1 l-1 5Z`, '#ead2a3', '#7298b0', .7);
  } else if (age === 11) {
    front += line(`M${60-hw*.64} ${bottom-2} Q60 ${bottom+10} ${60+hw*.64} ${bottom-2}`, '#5f7e82', 3);
    for(const side of [-1,1]) front += p(`M${60+side*18-3} ${bottom-5} q3-2 5 1 l1 7 q-3 4-6 0Z`, '#6c9295', '#537b80', .8);
  }
  return behind + face + front;
}
function body(age, bare = false) {
  const [, , , shoulder, hem, bw] = FORMS[age], left = 60-bw, right = 60+bw;
  const top = shoulder-4;
  let art = '';
  if (age === 6) {
    art += p(`M${left-3} ${top+3} Q${left-9} ${top+4} ${left-8} ${top+17} L${left-6} ${hem-5} Q${left-1} ${hem} ${left+6} ${hem-4} L${right-6} ${hem-4} Q${right+2} ${hem} ${right+7} ${hem-5} L${right+8} ${top+15} Q${right+9} ${top} ${right-4} ${top}Z`, '#9ac2b3', '#76a394', .9);
  }
  const shape = `M${left+7} ${top} Q60 ${top-4} ${right-7} ${top} C${right+1} ${top+3} ${right+3} ${hem-15} ${right-1} ${hem-6} Q${right-3} ${hem+2} 60 ${hem+2} Q${left+3} ${hem+2} ${left+1} ${hem-6} C${left-3} ${hem-15} ${left-1} ${top+3} ${left+7} ${top}Z`;
  art += p(shape, age <= 3 || bare ? 'url(#down)' : 'url(#cloth)', age <= 3 || bare ? INK : COLORS[age][1], .95);
  art += p(shape, 'url(#form-shade)');
  art += p(`M${left+10} ${top+2} Q60 ${top-1} ${right-10} ${top+2} L${right-8} ${top+16} Q60 ${top+22} ${left+8} ${top+16}Z`, 'url(#chin-shade)');
  if(bare) return art + p(`M47 ${top+16} C50 ${top+8} 66 ${top+7} 72 ${top+16} Q79 ${hem-7} 60 ${hem-2} Q42 ${hem-4} 47 ${top+16}Z`, 'url(#muzzle)');
  if (age === 0) {
    // The inset lip and inner wall give the shell thickness without moving its
    // anchored body layer. Only the head and wings articulate above it.
    art += p(`M${left} ${hem-20} Q60 ${hem-28} ${right+1} ${hem-21} L${right-2} ${hem-15} Q60 ${hem-21} ${left+2} ${hem-14}Z`, '#b9a477', '#b19a71', .6);
    art += p(`M${left-1} ${hem-19} Q${left+1} ${hem-24} ${left+4} ${hem-20} L${left+9} ${hem-15} L${left+15} ${hem-21} L${left+21} ${hem-16} L${left+29} ${hem-23} L${left+35} ${hem-17} L${right-3} ${hem-22} Q${right+2} ${hem-24} ${right+2} ${hem-17} Q${right+3} ${hem+3} 60 ${hem+4} Q${left-3} ${hem+3} ${left-1} ${hem-19}Z`, 'url(#shell)', '#c6b997', .9);
    art += line(`M${left+3} ${hem-19} L${left+9} ${hem-13.5} L${left+15} ${hem-19.5} L${left+21} ${hem-14.5} L${left+29} ${hem-21.5} L${left+35} ${hem-15.5} L${right-2} ${hem-20}`, '#fffdf1', 1.15);
    art += p(`M${left+3} ${hem-15} Q${left+5} ${hem-1} 57 ${hem+1} Q${left+1} ${hem+1} ${left+3} ${hem-15}Z`, '#fffef5', 'none', 0, 'opacity=".55"');
    art += line(`M${right-7} ${hem-12} l-2 4 2 2-2 3`, '#c5b38e', .65);
    art += e(49,hem-6,1.2,.8,'#d7c8a8') + e(68,hem-10,.8,1,'#d7c8a8') + e(65,hem,.9,.6,'#d7c8a8');
  } else if (age === 3) {
    art += p(`M43 ${top+4} Q60 ${top+10} 77 ${top+4} L75 ${top+17} Q60 ${top+30} 45 ${top+17}Z`, 'url(#cloth)', '#7fac9c', .9);
    art += line(`M46 ${top+9} Q60 ${top+14} 74 ${top+9}`, '#c6e2cb', .8);
    art += line(`M46 ${top+17} Q60 ${top+28} 74 ${top+17}`, '#629e8a', .65, 'opacity=".65"');
    art += p(`M${left+1} ${hem-9} Q60 ${hem-5} ${right-1} ${hem-9} L${right-3} ${hem+1} Q${right-9} ${hem+5} 62 ${hem} L59 ${hem-3} L56 ${hem+1} Q${left+4} ${hem+4} ${left+1} ${hem-9}Z`, '#a9cbbd', '#7fac9c', .8);
    art += p(`M58 ${top+15} q2-3 4 0 q-1 3-4 0Z`, '#fff2bb');
  } else if ([4,9].includes(age)) {
    art += p(`M${left+8} ${top+3} Q60 ${top+7} ${right-8} ${top+3} L${right-10} ${top+12} Q60 ${top+16} ${left+10} ${top+12}Z`, '#f9e4b4', '#d3b57e', .7);
    for(const x of [left+9,right-13]) {
      art += p(`M${x} ${top+2} l4 0 1 20-5 0Z`, COLORS[age][0], COLORS[age][1], .8);
      art += e(x+2.2,top+18,1.5,1.5,'#f4d594');
    }
    art += p(`M50 ${hem-19} Q60 ${hem-20} 70 ${hem-19} L68 ${hem-10} Q60 ${hem-7} 52 ${hem-10}Z`, COLORS[age][0], COLORS[age][1], .9);
    art += line(`M53 ${hem-17} L67 ${hem-17} M60 ${hem-5} L60 ${hem+1}`, '#d1dfe0', .7);
  } else if (age === 5) {
    art += line(`M60 ${top+3} L60 ${hem}`, '#c1935c', .85);
    art += p(`M45 ${top+3} l15 6-9 5Z M75 ${top+3} l-15 6 9 5Z`, '#f7d495', '#d7a361', .75);
    art += line(`M43 ${hem-16} l10 1 M67 ${hem-15} l10-1`, '#b88753', .85);
    for(const y of [top+17,top+25,top+33]) art += e(62.5,y,1,1,'#b98d59');
    art += line(`M${left+5} ${hem-2} Q60 ${hem+1} ${right-5} ${hem-2}`, '#f9da9b', .8);
  } else if ([6,10,12].includes(age)) {
    art += p(`M53 ${top+3} Q60 ${top+7} 67 ${top+3} L70 ${hem} Q60 ${hem+2} 51 ${hem}Z`, '#fbebce', '#d3b78c', .7);
    art += p(`M51 ${top+2} L57 ${top+10} L49 ${top+14} L53 ${hem} L${left+4} ${hem-1} Q${left} ${top+12} ${left+9} ${top+2}Z`, 'url(#cloth)', COLORS[age][1], .75);
    art += p(`M69 ${top+2} L63 ${top+10} L71 ${top+14} L68 ${hem} L${right-4} ${hem-1} Q${right} ${top+12} ${right-9} ${top+2}Z`, 'url(#cloth)', COLORS[age][1], .75);
    art += p(`M57 ${top+10} L49 ${top+14} L53 ${hem} L55 ${hem} L51 ${top+15}Z M63 ${top+10} L71 ${top+14} L68 ${hem} L66 ${hem} L69 ${top+15}Z`, '#7c5e46', 'none', 0, 'opacity=".16"');
    art += line(`M${left+10} ${top+5} L55 ${top+10} L47.8 ${top+14} M${right-10} ${top+5} L65 ${top+10} L72 ${top+14}`, '#fff6df', .7, 'opacity=".58"');
    art += line(`M${left+6} ${hem-3} Q${left+12} ${hem} 51 ${hem} M69 ${hem} Q${right-10} ${hem} ${right-5} ${hem-3}`, '#fff4da', .65, 'opacity=".5"');
    art += line(`M${left+8} ${hem-13} l6-1 M${right-14} ${hem-14} l6 1`, COLORS[age][1], 1);
    if(age===6) {
      art += line(`M${left+7} ${top+1} Q${left+2} ${top+15} ${left+6} ${hem-9} M${right-7} ${top+1} Q${right-2} ${top+15} ${right-6} ${hem-9}`, '#719e90', 3);
      art += line(`M${left+7} ${top+4} l-1 12 M${right-7} ${top+4} l1 12`, '#d6e0c3', .9);
    }
    if(age===12) {
      art += line(`M45 ${top+2} L78 ${hem-8}`, '#bda381', 4.6);
      art += line(`M45 ${top+2} L78 ${hem-8}`, '#e5d2af', 2.4);
      art += p(`M69 ${hem-16} q9-2 15 1 l-1 14 q-8 3-15-1Z`, '#d2b692', '#ac9274', .9);
      art += p(`M81 ${hem-14} l3-1-1 14-3 1Z`, '#af9271');
      art += p(`M69 ${hem-3} q6 2 11 1 l3 1 q-8 3-15-1Z`, '#b69a76');
      art += p(`M69 ${hem-16} q8-2 15 1 l-1 6 q-7 2-14-1Z`, '#e0c9a6', '#ac9274', .7);
      art += line(`M70 ${hem-15} q6-1 12 1`, '#fff0d2', .7, 'opacity=".7"');
      art += line(`M76 ${hem-12} l0 4`, '#997f64', 1.3);
    }
  } else if(age===7) {
    art += p(`M46 ${top+3} Q60 ${top+10} 74 ${top+3} L70 ${top+8} Q60 ${top+13} 49 ${top+8}Z`, '#e8e6c9', '#95a57d', .65);
    art += p(`M${left+2} ${top+13} Q54 ${top+21} ${right-1} ${hem-13} L${right-1} ${hem-7} Q56 ${top+29} ${left+2} ${top+19}Z`, '#e9ebd4');
    art += line(`M${left+4} ${hem-2} Q60 ${hem+1} ${right-4} ${hem-2}`, '#cad7b3', 1.2);
  } else if(age===8) {
    art += p(`M46 ${top+1} Q60 ${top+11} 74 ${top+1} L70 ${top+9} Q60 ${top+15} 49 ${top+9}Z`, '#d4c1df', '#a38baf', .75);
    art += line(`M55 ${top+11} L54 ${top+22} M65 ${top+11} L67 ${top+22}`, '#eee1ed', 1.2);
    art += p(`M51 ${hem-18} L68 ${hem-18} L74 ${hem-7} Q60 ${hem-3} 46 ${hem-7}Z`, '#c5afd3', '#a28bae', .8);
    art += line(`M51 ${hem-16} l-3 6 M68 ${hem-16} l4 6`, '#eee1ed', .65);
  } else if(age===11) {
    art += p(`M53 ${top+2} Q60 ${top+7} 67 ${top+2} L69 ${hem-3} L51 ${hem-3}Z`, '#eee0c5', '#b58c74', .7);
    art += line(`M60 ${top+6} L60 ${hem-4}`, '#bb997d', .7);
    art += p(`M${left+3} ${hem-4} Q60 ${hem} ${right-3} ${hem-4} L${right-3} ${hem+1} Q60 ${hem+4} ${left+3} ${hem+1}Z`, '#c8ad8e', '#a88770', .7);
    art += line(`M${left+4} ${hem-1} Q60 ${hem+2} ${right-4} ${hem-1}`, '#f5e3c7', 1.1);
    art += line(`M43 ${hem-15} l8-2 M69 ${hem-17} l8 2`, '#a77b67', .85);
  }
  return art;
}
function wing(age, side) {
  const [, , , shoulder,, bw] = FORMS[age];
  const root = 60-bw+8, y=shoulder+4, length=age<=3?16:age<=6?19:23;
  // Bury the narrow shoulder in the torso. The outer feathers broaden below
  // that joint instead of forming a separately outlined paddle at the collar.
  const upper = `M${root+3} ${y-5} C${root-2} ${y-7} ${root-8} ${y-4} ${root-10} ${y+2}`;
  const contour = `${upper} C${root-13} ${y+9} ${root-11} ${y+length-2} ${root-7} ${y+length+1} Q${root-5} ${y+length+3} ${root-3} ${y+length-1} Q${root} ${y+length+2} ${root+2} ${y+length-2} Q${root+5} ${y+length-1} ${root+5} ${y+length-6} C${root+5} ${y+7} ${root+8} ${y-1} ${root+3} ${y-5}Z`;
  // The mirrored wing uses the opposite gradient coordinates to preserve the
  // same upper-left light. Attachment shading stays on its body-facing edge.
  const mirror = content => side === 1 ? group(content, 'translate(120 0) scale(-1 1)') : content;
  let art = mirror(p(contour, side===1?'url(#down-right)':'url(#down)', INK, .5));
  art += mirror(p(`M${root+2} ${y+5} C${root-1} ${y+10} ${root+1} ${y+length-5} ${root-3} ${y+length-1} Q${root} ${y+length+2} ${root+2} ${y+length-2} Q${root+5} ${y+length-1} ${root+5} ${y+length-6} C${root+5} ${y+9} ${root+5} ${y+4} ${root+2} ${y+5}Z`, '#c4903c', 'none', 0, 'opacity=".09"'));
  art += mirror(p(`M${root-9} ${y+8} C${root-8} ${y+3} ${root-3} ${y-1} ${root} ${y} C${root-3} ${y+4} ${root-3} ${y+10} ${root-6} ${y+13} Q${root-10} ${y+15} ${root-9} ${y+8}Z`, '#fff3bd', 'none', 0, `opacity="${side===1?'.08':'.22'}"`));
  art += mirror(line(`M${root+1} ${y+12} Q${root+1} ${y+length-4} ${root-3} ${y+length-1} M${root-4} ${y+14} Q${root-5} ${y+length-4} ${root-7} ${y+length+1}`, '#c39345', .55, 'opacity=".55"'));
  if (age >= 4) {
    // The sleeve belongs to the moving wing and overlaps the matching jacket,
    // so its shoulder remains continuous through a raised or lowered pose.
    art += mirror(p(`${upper} Q${root-11} ${y+5} ${root-11} ${y+8} Q${root-3} ${y+12} ${root+5} ${y+8} C${root+6} ${y+3} ${root+7} ${y-2} ${root+3} ${y-5}Z`, 'url(#cloth)'));
    art += mirror(line(`M${root-11} ${y+8} Q${root-3} ${y+12} ${root+5} ${y+8}`, COLORS[age][1], .7));
    art += mirror(line(`M${root-10} ${y+6.8} Q${root-3} ${y+10.3} ${root+4.5} ${y+6.8}`, '#fff4da', .6, 'opacity=".5"'));
  }
  return art;
}
function foot(age, side) {
  const [, , , , hem] = FORMS[age];
  const x = age <= 3 ? 48 : 47, floor=110;
  let art;
  if(age===5) {
    art = p(`M${x-6} ${hem-3} L${x+5} ${hem-3} L${x+5} ${floor-4} Q${x+10} ${floor-4} ${x+10} ${floor} Q${x} ${floor+3} ${x-9} ${floor+1} L${x-8} ${floor-3}Z`, '#8caf93', '#719478', .9);
    art += line(`M${x-7} ${hem} L${x+4} ${hem} M${x-8} ${floor} Q${x} ${floor+2} ${x+9} ${floor}`, '#d0d9b7', 1.1);
  } else if(age>=7) {
    art = p(`M${x-3} ${hem-1} L${x+3} ${hem-1} L${x+3} ${floor-6} L${x-3} ${floor-6}Z`, '#edb571', '#cca065', .7);
    art += p(`M${x-4} ${floor-8} Q${x+2} ${floor-10} ${x+5} ${floor-5} L${x+9} ${floor-3} Q${x+10} ${floor+1} ${x+4} ${floor+1} L${x-9} ${floor+1} Q${x-11} ${floor-2} ${x-7} ${floor-4}Z`, '#f4edd7', '#aba98c', .8);
    art += p(`M${x-8} ${floor-3} L${x+6} ${floor-3} Q${x+10} ${floor-1} ${x+5} ${floor} L${x-8} ${floor}Z`, '#c5c5aa');
    art += line(`M${x-2} ${floor-6} l4 1 M${x-3} ${floor-4} l4 1`, '#819b94', .85);
  } else {
    art = p(`M${x-2} ${hem-3} Q${x+2} ${hem-2} ${x+3} ${hem+1} L${x+4} ${floor-4} Q${x+11} ${floor-2} ${x+10} ${floor+1} Q${x+4} ${floor+3} ${x} ${floor+1} Q${x-6} ${floor+3} ${x-10} ${floor+1} Q${x-12} ${floor-1} ${x-5} ${floor-5}Z`, 'url(#bill)', '#c58f5e', .8);
    art += line(`M${x-3} ${floor-2} l-1 2 M${x+2} ${floor-2} l1 2`, '#cb9460', .7);
  }
  return side===1 ? group(art, 'translate(120 0) scale(-1 1)') : art;
}
function layers(age, face='neutral') {
  return [body(age), head(age,face), wing(age,-1), wing(age,1), foot(age,-1), foot(age,1)];
}
async function render(age, previewOnly) {
  const dir=path.join(OUT,String(age)); fs.mkdirSync(dir,{recursive:true});
  const art=layers(age);
  const [, ,cy,shoulder,hem,bw]=FORMS[age];
  const metadata={age,style:'storybook',artSource:'tools/pip-growth/storybook.cjs',
    render:'Authored Pip illustration; directional matte form shading, curved bill and layered feathers; transparent 360 px layers',
    frameOffsetY:3, motionPivots:[[60,hem-2],[60,cy+FORMS[age][1]-5],[60-bw+8,shoulder+6],[60+bw-8,shoulder+6],[age<=3?48:47,hem],[age<=3?72:73,hem]],
    shadowRadius:age===0?29:28,cellPixels:360,coordinates:'120-unit front illustration',
    form:{headWidth:FORMS[age][0]*2,headHeight:FORMS[age][1]*2,headCenter:cy,shoulder,hem,torsoWidth:bw*2}};
  const full=[4,5,0,1,2,3].map(i=>art[i]).join('');
  fs.writeFileSync(path.join(dir,'storybook.svg'),svg(age,full,600));
  await sharp(Buffer.from(svg(age,full,600))).png().toFile(path.join(dir,'preview.png'));
  if(previewOnly) return;
  for(let i=0;i<PARTS.length;i++) await sharp(Buffer.from(svg(age,art[i]))).png().toFile(path.join(dir,PARTS[i]+'.png'));
  for(const face of FACES.slice(1)) await sharp(Buffer.from(svg(age,head(age,face)))).png().toFile(path.join(dir,face+'.png'));
  fs.writeFileSync(path.join(dir,'model.json'),JSON.stringify(metadata,null,2)+'\n');
}
function sourceGroup(source, id) {
  const start=source.indexOf(`<g id="${id}"`);
  if(start<0) throw new Error(`Missing acquired project wardrobe layer: ${id}`);
  let depth=0;
  for(const match of source.slice(start).matchAll(/<g\b[^>]*>|<\/g>/g)) {
    depth+=match[0]==='</g>'?-1:1;
    if(depth===0) return source.slice(start,start+match.index+match[0].length).replace(` id="${id}"`,'');
  }
  throw new Error(`Unbalanced wardrobe layer: ${id}`);
}
function softenWardrobe(source) {
  // Reuse the existing authored accessories, with quiet outlines and paper colors.
  return source.replace(/#[0-9a-f]{6}/gi, hex=>{
    const rgb=[1,3,5].map(i=>parseInt(hex.slice(i,i+2),16));
    const paper=[249,236,207];
    return '#'+rgb.map((v,i)=>Math.round(v*.76+paper[i]*.24).toString(16).padStart(2,'0')).join('');
  }).replace(/stroke-width="([\d.]+)"/g,(_,width)=>`stroke-width="${Number(width)*.48}"`);
}
function framed(age, content, key) {
  const source=defs(age)+`<g stroke="none" stroke-linecap="round" stroke-linejoin="round" filter="url(#paper)" transform="translate(0 3)">${content}</g>`;
  return source.replace(/id="([^"]+)"/g,(_,id)=>`id="${key}-${id}"`).replace(/url\(#([^)]+)\)/g,(_,id)=>`url(#${key}-${id})`);
}
function writeLoaderAssets() {
  const source=fs.readFileSync(path.join(ROOT,'assets/images/mascots/outfits/wardrobe.svg'),'utf8');
  const target=path.join(ROOT,'assets/images/mascots/storybook'); fs.mkdirSync(target,{recursive:true});
  const age=3, stages=[null,'spring','summer','autumn','winter','ocean','space','jungle','candy'];
  for(const theme of stages) {
    const key=theme||'base', clothing=theme?group(softenWardrobe(sourceGroup(source,`${theme}-body`)),'translate(60 -13.5) scale(.63 1.04) translate(-60 0)'):'';
    const hat=theme?group(softenWardrobe(sourceGroup(source,`${theme}-head`)),theme==='space'?'translate(60 8) scale(.81 .8) translate(-60 0)':'translate(60 4) scale(.78 .9) translate(-60 0)'):'';
    const renderParts=face=>[body(age,true)+clothing,head(age,face)+hat,wing(age,-1),wing(age,1),foot(age,-1),foot(age,1)];
    const parts=renderParts('neutral');
    const stem=theme?`pip-${theme}`:'pip';
    const sheet=(cells,description)=>`<svg xmlns="http://www.w3.org/2000/svg" width="${cells.length*120}" height="120" viewBox="0 0 ${cells.length*120} 120"><title>Storybook Pip ${key}; ${description}; adapted original project art</title><g>${cells.map((cell,i)=>`<g transform="translate(${i*120} 0)">${framed(age,cell,`${key}-${description}-${i}`)}</g>`).join('')}</g></svg>\n`;
    fs.writeFileSync(path.join(target,`${stem}-parts.svg`),sheet(parts,'parts'));
    const poses=['neutral','speaking','blink','encourage'].map((face,i)=>{
      const frame=renderParts(face);
      if(i===3) frame[2]=group(frame[2],`rotate(70 ${60-FORMS[age][5]+8} ${FORMS[age][3]+6})`);
      return e(60,111.5,28,4.5,'url(#ground)')+[4,5,0,1,2,3].map(j=>frame[j]).join('');
    });
    fs.writeFileSync(path.join(target,`${stem}.svg`),sheet(poses,'poses'));
  }
  fs.writeFileSync(path.join(target,'.gdignore'),'');
  console.log('Storybook loading and speech artwork: base plus eight original project wardrobes.');
}
async function main() {
  const selected=process.argv.find(a=>a.startsWith('--ages='));
  const ages=selected?selected.slice(7).split(',').map(Number):AGES;
  for(const age of ages) {
    if(!AGES.includes(age)) throw new Error(`Unknown Pip age: ${age}`);
    await render(age,process.argv.includes('--preview'));
    console.log(`Pip storybook layers rendered: ${age===0?'Baby':age}`);
  }
  if(!process.argv.includes('--preview')) writeLoaderAssets();
}
if(require.main===module) main().catch(error=>{console.error(error);process.exitCode=1;});
module.exports={svg,layers,head,AGES,FORMS};
