'use strict';

// Career wardrobes extend the already integrated Pip illustration and rig.
// They use the same source face, attached shoulders, matte shading and paper.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require(process.env.SHARP_MODULE || 'sharp');
const Pip = require('./storybook.cjs');
const ROOT = path.resolve(__dirname, '../..');
const TARGET = path.join(ROOT, 'assets/images/mascots/professional');
const REVIEW = path.join(ROOT, 'build/professional-pip');
const AGE = 12;
const SIZE = 360;
const FACES = ['neutral', 'listening', 'thinking', 'delighted', 'proud', 'encourage', 'surprised', 'sleepy', 'wink', 'blink'];
const ORDER = [4, 5, 0, 1, 2, 3];
const JOINTS = [[60, 100], [60, 56.5], [45, 67], [75, 67], [47, 102], [73, 102]];
const p = (d, fill, stroke = 'none', width = .8, extra = '') => `<path d="${d}" fill="${fill}" stroke="${stroke}" stroke-width="${width}" ${extra}/>`;
const l = (d, stroke, width = .8, extra = '') => p(d, 'none', stroke, width, extra);
const e = (x, y, rx, ry, fill, extra = '') => `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="${fill}" ${extra}/>`;
const g = (content, transform = '') => `<g transform="${transform}">${content}</g>`;
const PROFILES = {
  caregiving: {garment:'cardigan', cloth:['#dfb5a3','#b98a7b'], trim:'#aec4ac', accessory:'heart', description:'A soft peach cardigan, sage collar and a stitched heart pocket.'},
  retail: {garment:'apron', cloth:['#a6c9bd','#6f9d90'], trim:'#557f71', accessory:'badge', description:'A forest-green shop apron with a stitched pocket and name badge.'},
  food_service: {garment:'chef', cloth:['#f5eddd','#d5c8b3'], trim:'#a46150', hat:'chef', description:'A soft chef toque, folded neckerchief and double-breasted cream jacket.'},
  nursing: {garment:'scrubs', cloth:['#9ccfc6','#68a69e'], trim:'#d7e9de', accessory:'stethoscope', description:'Teal scrubs, rounded patch pockets, an ID clip and a stethoscope.'},
  customer_support: {garment:'cardigan', cloth:['#c4b0cf','#9d86ac'], trim:'#eee4cc', hat:'headset', description:'A lavender cardigan and a softly padded customer-service headset.'},
  office_admin: {garment:'blazer', cloth:['#a4b3c3','#74889f'], trim:'#c58b75', accessory:'badge', description:'A slate-blue blazer, coral collar and clipped office badge.'},
  warehouse_logistics: {garment:'vest', cloth:['#a0aeb2','#778c94'], trim:'#e8bd70', hat:'cap', description:'A warm amber safety vest with reflective bands and a slate work cap.'},
  hospitality_tourism: {garment:'waistcoat', cloth:['#b19aaa','#806878'], trim:'#ead9b9', accessory:'bowtie', description:'A plum hospitality waistcoat with a cream collar and bow tie.'},
  transport_delivery: {garment:'jacket', cloth:['#95b5c3','#638a9e'], trim:'#d69475', hat:'cap', description:'A blue delivery jacket, coral cap and a securely attached shoulder strap.'},
  construction_trades: {garment:'vest', cloth:['#c2b49d','#948975'], trim:'#e7ae67', hat:'hardhat', description:'An amber hard hat and reflective ochre work vest over a canvas shirt.'},
  cleaning_facilities: {garment:'apron', cloth:['#9ac7cf','#6b9fab'], trim:'#e4c382', hat:'bandana', description:'An aqua work apron, folded golden head scarf and practical patch pocket.'},
  education_childcare: {garment:'cardigan', cloth:['#b1bbd6','#8795b8'], trim:'#dfbe7b', accessory:'pencils', description:'A periwinkle cardigan with a warm scarf and colored pencils in the pocket.'},
  manufacturing_maintenance: {garment:'coverall', cloth:['#8eacc0','#637f9b'], trim:'#d7b77b', hat:'safety-glasses', description:'Blue work coveralls, a reinforced collar and clear protective glasses.'},
  it_support: {garment:'vest', cloth:['#a4bec3','#75979e'], trim:'#6e8a9e', hat:'headset', description:'A teal shirt, navy utility vest and a compact technical-support headset.'},
  software_data: {garment:'hoodie', cloth:['#9caac6','#707e9f'], trim:'#c9d4dc', hat:'glasses', description:'A soft indigo hoodie, roomy kangaroo pocket and round blue glasses.'},
  accounting_finance: {garment:'blazer', cloth:['#a9b9b4','#788f87'], trim:'#bc986a', hat:'glasses', accessory:'tie', description:'A sage tailored jacket, warm gold tie and slender reading glasses.'},
  sales_marketing: {garment:'blazer', cloth:['#d0a194','#a77368'], trim:'#e7c78d', accessory:'scarf', description:'A terracotta jacket and a flowing golden scarf tucked beneath the lapel.'},
  hr_recruitment: {garment:'cardigan', cloth:['#b5c3a6','#8b9d7b'], trim:'#e2b5a1', accessory:'badge', description:'A moss-green cardigan, peach collar and carefully clipped name badge.'},
  clinical_medicine: {garment:'coat', cloth:['#eceadf','#c7cbbb'], trim:'#9abdb8', accessory:'stethoscope', description:'A warm white consultation coat over a teal shirt, with a stethoscope and ID.'},
  legal_paralegal: {garment:'blazer', cloth:['#abb0c4','#7c829b'], trim:'#a97778', accessory:'tie', description:'A violet-blue suit jacket, muted burgundy tie and neatly stitched document pocket.'},
};

function shirt(profile) {
  const [cloth, fold] = profile.cloth;
  const shape = 'M44 55 Q60 51 76 55 C84 58 86 84 82 94 Q81 102 60 102 Q39 102 38 94 C34 84 36 58 44 55Z';
  let art = p(shape, 'url(#cloth)', fold, .9) + p(shape, 'url(#form-shade)');
  art += p('M47 55 Q60 52 73 55 L74 67 Q60 74 46 67Z', 'url(#chin-shade)');
  art += l('M41 76 Q43 88 41 94 M78 77 Q77 87 79 94 M45 99 Q60 103 76 99', fold, .7, 'opacity=".5"');
  art += l('M42 72 Q42 65 46 61', '#fff8e3', .9, 'opacity=".38"');
  return art;
}
function pocket(x, y, color, fold, width = 13) {
  return p(`M${x} ${y} Q${x+width/2} ${y+1.6} ${x+width} ${y} L${x+width-1} ${y+10} Q${x+width/2} ${y+13} ${x+1} ${y+10}Z`, color, fold, .65)
    + l(`M${x+1} ${y+2.4} Q${x+width/2} ${y+3.4} ${x+width-1} ${y+2.4}`, '#fff4d9', .6, 'opacity=".45"');
}
function collar(color, fold) {
  return p('M48 56 L59 66 L51 72 L45 58Z M72 56 L61 66 L69 72 L75 58Z', color, fold, .6);
}
function outfit(profile) {
  const [cloth, fold] = profile.cloth, trim = profile.trim;
  let art = shirt(profile);
  if (profile.garment === 'apron') {
    art += collar('#f5ebd6', fold);
    art += p('M49 57 L52 72 L68 72 L71 57 L75 58 L72 76 L79 98 Q60 105 41 98 L48 76 L45 58Z', trim, fold, .8);
    art += l('M49 58 L53 75 M71 58 L67 75 M44 97 Q60 102 76 97', '#efe2bd', .9, 'opacity=".65"');
    art += pocket(51, 83, trim, fold, 18);
    art += l('M45 82 Q49 81 51 84 M73 81 Q70 81 68 84', fold, .75);
  } else if (['blazer','coat','jacket'].includes(profile.garment)) {
    art += p('M48 55 Q60 62 72 55 L73 100 L47 100Z', profile.garment === 'coat' ? trim : '#f3ead6');
    art += p('M47 55 L57 65 L49 73 L56 78 L53 101 L40 98 Q36 81 40 62Z M73 55 L63 65 L71 73 L64 78 L67 101 L80 98 Q84 81 80 62Z', 'url(#cloth)', fold, .8);
    art += l('M48 56 L52 67 L47 73 M72 56 L68 67 L73 73', '#fff7e4', .7, 'opacity=".6"');
    art += l('M42 87 L50 88 M70 88 L78 87', fold, 1.1);
    art += e(63,84,1.05,1.05,trim) + e(63,93,1.05,1.05,trim);
    if(profile.garment==='jacket') art += p('M43 59 L47 58 L78 98 L73 100Z', trim, fold, .5) + l('M45 60 L75 98', '#ecd8b1', .6);
  } else if(profile.garment==='cardigan') {
    art += p('M50 55 Q60 61 70 55 L66 100 L54 100Z', '#f1e8d2');
    art += p('M48 55 L57 65 L56 101 Q45 102 39 97 L38 68Z M72 55 L63 65 L64 101 Q75 102 81 97 L82 68Z', 'url(#cloth)', fold, .65);
    art += l('M56 68 L55 99 M64 68 L65 99', '#f9efda', .8, 'opacity=".6"');
    art += collar(trim, fold);
    for(const y of [78,86,94]) art += e(63.6,y,1.1,1.1,'#f0dbac');
    art += pocket(42,83,cloth,fold,11) + pocket(68,83,cloth,fold,10);
  } else if(profile.garment==='scrubs') {
    art += p('M49 55 L60 67 L71 55 L74 58 L60 73 L46 58Z', trim, fold, .65);
    art += l('M49 57 L60 69 L71 57', '#f1f0d8', .65);
    art += pocket(43,84,cloth,fold) + pocket(65,84,cloth,fold);
    art += l('M41 98 Q60 101 79 98', fold,.7);
  } else if(profile.garment==='chef') {
    art += collar('#fff7e6', fold);
    art += p('M50 58 L60 65 L70 58 L66 70 L60 73 L54 70Z', trim, '#98624e', .6);
    art += p('M60 69 L65 74 L61 82 L57 75Z', trim, '#98624e', .6);
    art += l('M54 73 L54 98 M43 98 Q60 102 77 98', fold,.7);
    for(const x of [57,68]) for(const y of [83,91]) art += e(x,y,1.2,1.2,'#9b8e76');
    art += pocket(41,83,cloth,fold,10);
  } else if(profile.garment==='vest') {
    art += collar('#ece5d2', fold);
    art += p('M44 55 L54 65 L56 101 L40 98 L39 77 Q45 67 44 55Z M76 55 L66 65 L64 101 L80 98 L81 77 Q75 67 76 55Z', trim, fold,.75);
    art += l('M51 65 L53 99 M69 65 L67 99', '#f6ebce',1.2);
    if(profile.hat!=='headset') {
      art += p('M42 81 L54 82 L54 86 L41 85Z M66 82 L78 81 L79 85 L66 86Z', '#ecebd4', '#a7aa95',.4);
      art += l('M47 60 L49 78 M73 60 L71 78', '#eee9cd',2.2);
    }
    art += pocket(42,88,trim,fold,10) + pocket(68,88,trim,fold,10);
  } else if(profile.garment==='waistcoat') {
    art += collar('#f3ead6', fold);
    art += p('M47 56 L60 75 L73 56 L78 60 L77 96 L64 102 L60 97 L56 102 L43 96 L42 61Z','url(#cloth)',fold,.8);
    art += l('M60 75 L60 97 M47 88 L54 87 M66 87 L73 88', fold,.8);
    for(const y of [79,86,93]) art += e(60,y,.9,.9,'#e6cfa2');
  } else if(profile.garment==='coverall') {
    art += collar('#b9cad2', fold) + l('M60 68 L60 101', '#e5d6b4',1.2);
    art += pocket(43,70,cloth,fold) + pocket(65,70,cloth,fold);
    art += p('M40 88 Q60 91 80 88 L80 92 Q60 95 40 92Z',fold);
    art += p('M57 89 L63 89 L63 94 L57 94Z',trim, '#897859',.6);
    art += l('M48 94 L47 100 M72 94 L73 100',fold,.8);
  } else if(profile.garment==='hoodie') {
    art += p('M47 54 Q60 64 73 54 L80 60 Q75 77 60 75 Q45 77 40 60Z','url(#cloth)',fold,.8);
    art += p('M49 57 Q60 65 71 57 L67 65 Q60 69 53 65Z',trim,fold,.6);
    art += l('M54 67 L53 78 M66 67 L67 78', '#eee6cf',1.2);
    art += pocket(47,83,cloth,fold,26) + l('M49 84 L53 90 M71 84 L67 90',fold,.8);
    art += l('M41 98 Q60 102 79 98','#d0d8df',2);
  }
  if(profile.accessory==='stethoscope') {
    art += l('M49 58 C46 67 49 75 54 76 C59 77 62 72 61 65 M73 59 C76 68 71 77 68 81 L68 84', '#537c80',1.6);
    art += e(68,85,3,3,'#e4e8df','stroke="#6b8e90" stroke-width=".8"') + e(68,85,1.6,1.6,'#a6c0bf');
    art += badge(43,76);
  } else if(profile.accessory==='badge') art += badge(68,74);
  else if(profile.accessory==='bowtie') art += p('M58 66 L51 63 Q49 67 51 71 L58 69Z M62 66 L69 63 Q71 67 69 71 L62 69Z',profile.trim,profile.cloth[1],.6) + e(60,67.5,2.2,2.2,profile.trim);
  else if(profile.accessory==='tie') art += p('M57 61 L63 61 L62 67 L65 83 L60 88 L55 83 L58 67Z',trim,fold,.5) + l('M59 69 L57 82', '#efd4b1',.5);
  else if(profile.accessory==='scarf' || profile.accessory==='pencils') {
    art += p('M47 57 Q60 65 73 57 L73 63 Q60 71 47 63Z',trim,fold,.6) + p('M67 64 L72 63 L74 84 L68 81 L65 84Z',trim,fold,.6);
    art += l('M49 60 Q60 67 71 60', '#f8e7bd',.7);
    if(profile.accessory==='pencils') {
      art += l('M44 84 L44 77', '#c77f6b',1.5) + l('M47 85 L48 76', '#e2bd65',1.5) + l('M50 84 L51 78', '#7ca9b1',1.5);
      art += pocket(42,84,cloth,fold,11);
    }
  } else if(profile.accessory==='heart') art += p('M46 88 C42 85 43 82 46 83 Q48 81 49 84 Q51 87 46 90Z','#d7a08c','#ac796f',.5);
  return art;
}
function badge(x,y) {
  return p(`M${x+3} ${y-4} l2 0 0 4-2 0Z`,'#a29b84') + p(`M${x} ${y} q4-1 8 0 l0 7 q-4 1-8 0Z`,'#f3e9d0','#a9ab99',.55)
    + e(x+2.4,y+2.5,1.1,1.2,'#9bb9b0') + l(`M${x+4.5} ${y+2} l2 0 M${x+4.5} ${y+4} l2 0`,'#a9a995',.55);
}
function headwear(profile) {
  const [cloth,fold] = profile.cloth, trim=profile.trim;
  let art='';
  if(profile.hat==='chef') {
    art += p('M43 20 Q37 16 41 11 Q39 4 48 5 Q53 0 59 5 Q66 0 72 6 Q82 4 81 12 Q86 17 77 21 L75 27 Q60 22 45 27Z','#f6efe0','#c7bca4',.85);
    art += l('M48 9 Q46 14 49 19 M61 8 L61 18 M73 10 Q75 15 72 19','#e0d6c0',1);
    art += p('M44 20 Q60 17 77 20 L76 27 Q60 23 45 27Z','#eae3d0','#c7bca4',.7);
    art += l('M47 23 Q60 20 74 23','#fff9e9',.8);
  } else if(profile.hat==='cap') {
    const cap=profile.garment==='jacket'?trim:cloth;
    art += p('M36 25 Q35 9 52 9 Q74 5 83 25 Q60 20 36 25Z',cap,fold,.85);
    art += p('M37 25 Q62 20 83 25 Q93 26 91 30 Q85 32 78 28 Q60 25 38 28Z',cap,fold,.8);
    art += l('M59 10 Q66 16 65 23','#f6e4c6',.8,'opacity=".6"') + e(59,9,2,1.3,trim);
  } else if(profile.hat==='hardhat') {
    art += p('M36 25 Q36 10 49 10 Q60 6 72 10 Q83 12 84 25Z','#e5b568','#b68a4c',.85);
    art += p('M56 8 Q60 6 64 8 L67 25 L54 25Z','#f3cf8a','#c69a58',.7);
    art += p('M34 24 Q60 20 86 24 L87 28 Q61 30 33 28Z','#f0c779','#b68a4c',.8);
    art += l('M40 21 Q42 14 49 13 M59 10 L58 22','#fff0ba',1,'opacity=".65"');
  } else if(profile.hat==='bandana') {
    art += p('M37 25 Q37 10 59 9 Q80 10 83 25 Q60 19 37 25Z',trim,fold,.7);
    art += p('M77 23 Q83 15 87 20 L85 28 L91 30 L82 31 L78 26Z',trim,fold,.65);
    art += l('M45 16 Q59 10 73 17 M39 23 Q60 18 81 23','#fff0cb',.8);
  } else if(profile.hat==='headset') {
    art += l('M37 41 C28 9 88 4 85 41','#6b7f83',2.5);
    art += l('M39 20 Q60 5 79 20','#bcc9c8',1.2);
    for(const x of [36,84]) art += p(`M${x-2} 34 q3-2 5 1 l0 10 q-2 4-5 0Z`,'#8eabad','#607e82',.8);
    art += l('M87 43 Q88 54 74 55','#607e82',1.1) + e(73,55,2.4,1.35,'#607e82');
  } else if(['glasses','safety-glasses'].includes(profile.hat)) {
    const safety=profile.hat==='safety-glasses';
    for(const x of [51.2,68.8]) art += e(x,35.2,6.8,6.4,safety?'#dbe8e2':'none',`stroke="${safety?'#7d999e':'#6d8499'}" stroke-width="1.1" ${safety?'fill-opacity=".14"':''}`);
    art += l('M58 34 Q60 32.8 62 34 M44 33.5 L39.5 31 M76 33.5 L80.5 31', '#6d8499',1);
    if(safety) art += l('M45 30 L51 28 M64 30 L70 28','#f7f0d7',.7,'opacity=".8"');
  }
  return art;
}
function layers(profile, face='neutral') {
  Pip.COLORS[AGE]=profile.cloth;
  return [outfit(profile), Pip.head(AGE,face)+headwear(profile), Pip.wing(AGE,-1), Pip.wing(AGE,1), Pip.foot(AGE,-1), Pip.foot(AGE,1)];
}
function composition(profile, face='neutral', pose={}) {
  const parts=layers(profile,face);
  return e(60,111,28,4.5,'url(#ground)')+ORDER.map(index=>{
    const [x,y,rotation]=pose[index]||[0,0,0];
    return g(parts[index],`translate(${x} ${y}) rotate(${rotation} ${JOINTS[index][0]} ${JOINTS[index][1]-3})`);
  }).join('');
}
function sheet(profile, cells, name) {
  Pip.COLORS[AGE]=profile.cloth;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${SIZE*cells.length}" height="${SIZE}" viewBox="0 0 ${120*cells.length} 120"><title>${name.replaceAll('&','&amp;')}</title>${cells.map((cell,index)=>g(Pip.framed(AGE,cell,`career-${index}`),`translate(${index*120} 0)`)).join('')}</svg>`;
}
async function writeCareer(id, profile, title) {
  const stem=`pip-${id.replaceAll('_','-')}`;
  const cells={
    regular:['neutral','speaking','blink','encourage'].map((face,i)=>composition(profile,face,i===3?{2:[0,0,70],1:[0,0,4]}:{})),
    idle:[composition(profile,'thinking',{1:[-1,-.5,-5]}),composition(profile,'proud',{1:[0,-2,0],2:[0,0,35],3:[0,0,-35]}),composition(profile,'wink',{1:[1,0,5]}),composition(profile,'sleepy',{1:[1,2,8],2:[0,0,25]})],
    parts:layers(profile),
    expressions:FACES.map(face=>composition(profile,face)),
    expressionHeads:FACES.map(face=>layers(profile,face)[1]),
  };
  const suffixes={regular:'',idle:'-idle',parts:'-parts',expressions:'-expressions',expressionHeads:'-expression-heads'};
  const art={}, hashes={};
  for(const [kind,frames] of Object.entries(cells)) {
    const name=`${stem}${suffixes[kind]}.png`;
    const input=sheet(profile,frames,`${title} Pip; ${kind}; adapted original project art`);
    const bytes=await sharp(Buffer.from(input)).png({compressionLevel:9}).toBuffer();
    fs.writeFileSync(path.join(TARGET,name),bytes);
    art[kind]=`assets/images/mascots/professional/${name}`;
    hashes[kind]=crypto.createHash('sha256').update(bytes).digest('hex');
  }
  fs.writeFileSync(path.join(REVIEW,`${id}.svg`),sheet(profile,[composition(profile)],`${title} Pip`));
  await sharp(path.join(TARGET,`${stem}.png`)).extract({left:0,top:0,width:SIZE,height:SIZE}).toFile(path.join(REVIEW,`${id}.png`));
  return {course_id:id,title,description:profile.description,accent:profile.cloth[1],art,sha256:hashes,motionPivots:JOINTS,shadowRadius:28,actions:['wave','look','high-five'],source:'tools/pip-growth/professional.cjs'};
}
async function contact(catalog) {
  const width=1440, height=1100;
  let backdrop=`<svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="#f7f3e8"/><text x="26" y="35" font-family="Segoe UI" font-size="23" fill="#344e4b">Pip's professional wardrobes</text><text x="26" y="60" font-family="Segoe UI" font-size="13" fill="#677672">Integrated storybook artwork · six attached layers · 44 px and 56 px header checks</text>`;
  const parts=[];
  for(let index=0;index<catalog.length;index++) {
    const item=catalog[index],x=16+(index%5)*286,y=82+Math.floor(index/5)*253;
    backdrop+=`<rect x="${x}" y="${y}" width="274" height="242" rx="16" fill="#fffcf4" stroke="#e7e0d2"/><text x="${x+12}" y="${y+20}" font-family="Segoe UI" font-size="12" fill="#344e4b">${item.title.replaceAll('&','&amp;')}</text><rect x="${x+12}" y="${y+179}" width="250" height="54" rx="11" fill="#e6ece1"/>`;
    for(const [size,dx,dy] of [[151,62,26],[44,82,185],[56,145,179]]) parts.push({input:await sharp(path.join(REVIEW,`${item.course_id}.png`)).resize(size,size).toBuffer(),left:x+dx,top:y+dy});
  }
  backdrop+='</svg>';
  await sharp(Buffer.from(backdrop)).composite(parts).png().toFile(path.join(REVIEW,'all-careers.png'));
}
async function main() {
  fs.mkdirSync(TARGET,{recursive:true}); fs.mkdirSync(REVIEW,{recursive:true});
  if(process.argv.includes('--check')) return verify();
  const courses=JSON.parse(fs.readFileSync(path.join(ROOT,'data/professional/catalog.json'),'utf8')).courses;
  const catalog=[];
  for(const course of courses) {
    if(!PROFILES[course.id]) throw new Error(`Missing wardrobe: ${course.id}`);
    catalog.push(await writeCareer(course.id,PROFILES[course.id],course.title));
    console.log(`Prepared career Pip: ${course.title}`);
  }
  fs.writeFileSync(path.join(ROOT,'data/pip-professional.json'),JSON.stringify({schema_version:1,source:'Original project storybook Pip, adapted locally by Codex; repository ISC declaration; original illustrator not recorded.',cell_pixels:SIZE,profiles:catalog},null,2)+'\n');
  await contact(catalog);
  await verify();
  console.log(`Prepared ${catalog.length*5} career atlases and a phone-scale source review.`);
}
async function verify() {
  const catalog=JSON.parse(fs.readFileSync(path.join(ROOT,'data/pip-professional.json'),'utf8'));
  const report=[];
  for(const profile of catalog.profiles) for(const [kind,file] of Object.entries(profile.art)) {
    const {data,info}=await sharp(path.join(ROOT,file)).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    for(let cell=0;cell<info.width/SIZE;cell++) {
      let x0=SIZE,y0=SIZE,x1=0,y1=0;
      for(let y=0;y<SIZE;y++) for(let x=0;x<SIZE;x++) {
        if(data[(y*info.width+cell*SIZE+x)*4+3]>3) {x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y);}
      }
      if(x0<3||y0<3||x1>=SIZE-3||y1>=SIZE-3||x0>=x1||y0>=y1) throw new Error(`Clipped or missing career frame: ${profile.course_id}/${kind}/${cell} ${[x0,y0,x1,y1]}`);
      report.push({course_id:profile.course_id,kind,cell,bounds:[x0,y0,x1,y1]});
    }
  }
  fs.writeFileSync(path.join(REVIEW,'frame-bounds.json'),JSON.stringify(report,null,2)+'\n');
  console.log(`Verified ${report.length} transparent career frame bounds.`);
}
if(require.main===module) main().catch(error=>{console.error(error);process.exitCode=1;});
module.exports={PROFILES,layers,sheet,composition,JOINTS};
