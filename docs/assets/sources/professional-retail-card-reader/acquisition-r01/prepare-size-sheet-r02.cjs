'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const sharp=require('C:/Users/yaohuiwang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const hash=raw=>crypto.createHash('sha256').update(raw).digest('hex');
async function main(){
  const raw=fs.readFileSync(path.join(__dirname,'206301-cropped-512.png'));
  assert.equal(hash(raw),'67cb3e6f8e0be881b51a7d18ecc28fd1a02fab6b650197a8d60ef9d550b07c59');
  const width=840,height=630;
  const layers=[{input:raw,top:20,left:20}],rectangles=[{size:512,x:20,y:20,width:512,height:433}];
  for(const [index,size]of [64,96,128,192].entries()){
    const top=50+index*120,left=600;
    assert(left+size<=width&&top+size<=height);
    layers.push({input:await sharp(raw).resize(size,size,{fit:'contain',background:'#ffffff00'}).png().toBuffer(),top,left});
    rectangles.push({size,x:left,y:top,width:size,height:size});
  }
  const output=await sharp({create:{width,height,channels:4,background:'#f3f6f4'}}).composite(layers).png().toBuffer();
  const name='206301-size-review-r02.png';fs.writeFileSync(path.join(__dirname,name),output,{flag:'wx'});
  const receipt={schema:1,recorded_at:new Date().toISOString(),purpose:'Correct the clipped 192-pixel sample; original r01 sheet remains unchanged.',file:name,bytes:output.length,sha256:hash(output),width,height,rectangles,production_changes:false};
  fs.writeFileSync(path.join(__dirname,'size-review-r02-receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
  console.log(JSON.stringify(receipt));
}
main().catch(error=>{console.error(error);process.exitCode=1;});
