'use strict';
// Consult original publisher HTML in memory; retain metadata and hashes only.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../../..');
assert.equal(root.replaceAll('\\','/').toLowerCase(),'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const out=path.join(__dirname,'oxford-html-metadata.json');assert(!fs.existsSync(out),'Do not replay this completed consultation.');
const sha=x=>crypto.createHash('sha256').update(x).digest('hex');
const sourceHash=sha(fs.readFileSync(__filename));
const words=['correct_2','adjust','reschedule','postpone','cancel','resolve_1','assist','verify','locate','attach'];
const attrs=tag=>Object.fromEntries([...tag.matchAll(/([\w-]+)="([^"]*)"/g)].filter(m=>['id','class','sensenum','cefr','fkcefr','ox3000','ox5000'].includes(m[1])).map(m=>[m[1],m[2]]));
async function consult(word){
  const url='https://www.oxfordlearnersdictionaries.com/definition/english/'+word,startedAt=new Date().toISOString();
  try{
    const response=await fetch(url,{signal:AbortSignal.timeout(30000)}),body=Buffer.from(await response.arrayBuffer()),html=body.toString('utf8');
    return {term:word.replace(/_[12]$/,''),url,response_url:response.url,consulted_at:startedAt,http_status:response.status,content_type:response.headers.get('content-type'),raw_body_bytes:body.length,raw_body_sha256:sha(body),sense_elements:[...html.matchAll(/<[^>]+class="sense"[^>]*>/g)].map(m=>({html_offset:m.index,attributes:attrs(m[0])})),level_elements:[...html.matchAll(/<[^>]+(?:cefr|fkcefr)="[^"]*"[^>]*>/g)].map(m=>({html_offset:m.index,attributes:attrs(m[0])})),source_page_retained:false};
  }catch(error){return {term:word.replace(/_[12]$/,''),url,consulted_at:startedAt,error:String(error),source_page_retained:false};}
}
(async()=>{
  const observations=[];
  for(let i=0;i<words.length;i+=3)observations.push(...await Promise.all(words.slice(i,i+3).map(consult)));
  assert.equal(sha(fs.readFileSync(__filename)),sourceHash,'Consultation source changed during execution.');
  const record={schema:1,status:'source_metadata_observations_not_independent_acceptance',method:'Direct HTTP retrieval of original Oxford publisher pages. Bodies were inspected in memory for sense and level attributes; only minimal metadata and hashes are retained. Rendered meaning and usage were separately consulted with the web connector. No source text, source media or exercises are imported.',script_raw_sha256:sourceHash,recorded_at:new Date().toISOString(),observations};
  fs.writeFileSync(out,JSON.stringify(record,null,2)+'\n',{flag:'wx'});
  console.log(JSON.stringify(record,null,2));
})().catch(error=>{console.error(error);process.exitCode=1;});
