'use strict';
// Independent HTTP observations only. No publisher body is retained.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const sha=raw=>crypto.createHash('sha256').update(raw).digest('hex');
const output=path.join(__dirname,'oxford-html-metadata.json');
if(fs.existsSync(output))throw Error('Retain existing observations');
const words=['broken_1','urgent','unclear','safe_1','unsafe','hazard_1','incident_1','concern_2','solution','procedure'];
const attributes=tag=>Object.fromEntries([...tag.matchAll(/([\w-]+)="([^"]*)"/g)].filter(match=>['id','class','sensenum','cefr','fkcefr','ox3000','ox5000'].includes(match[1])).map(match=>[match[1],match[2]]));
const scriptHash=sha(fs.readFileSync(__filename));
fs.writeFileSync(path.join(__dirname,'collection-start.json'),JSON.stringify({schema:1,started_at:new Date().toISOString(),script_raw_sha256:scriptHash,urls:words.map(word=>'https://www.oxfordlearnersdictionaries.com/definition/english/'+word)},null,2)+'\n',{flag:'wx'});
async function observe(word){const url='https://www.oxfordlearnersdictionaries.com/definition/english/'+word,started=new Date().toISOString();try{
  const response=await fetch(url,{signal:AbortSignal.timeout(30000)}),bytes=Buffer.from(await response.arrayBuffer()),html=bytes.toString('utf8');
  return{term:word.replace(/_[12]$/,''),url,response_url:response.url,consulted_at:started,http_status:response.status,content_type:response.headers.get('content-type'),raw_body_bytes:bytes.length,raw_body_sha256:sha(bytes),
    sense_elements:[...html.matchAll(/<[^>]+class="sense"[^>]*>/g)].map(match=>({html_offset:match.index,attributes:attributes(match[0])})),
    level_elements:[...html.matchAll(/<[^>]+(?:cefr|fkcefr)="[^"]*"[^>]*>/g)].map(match=>({html_offset:match.index,attributes:attributes(match[0])})),source_page_retained:false};
}catch(error){return{term:word.replace(/_[12]$/,''),url,consulted_at:started,error:String(error),source_page_retained:false};}}
(async()=>{const observations=[];for(let at=0;at<words.length;at+=3)observations.push(...await Promise.all(words.slice(at,at+3).map(observe)));
if(sha(fs.readFileSync(__filename))!==scriptHash)throw Error('Collector drift');
const record={schema:1,status:'fresh_original_publisher_metadata_not_acceptance',recorded_at:new Date().toISOString(),script_raw_sha256:scriptHash,method:'HTTP bytes hashed in memory. Only sense/level attributes retained; selected meanings separately consulted through the web connector. Absence of an attribute is not a level assignment.',observations};
fs.writeFileSync(output,JSON.stringify(record,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(observations.map(row=>({term:row.term,status:row.http_status,error:row.error,senses:row.sense_elements})),null,2));
})().catch(error=>{fs.writeFileSync(path.join(__dirname,'collection-failure.json'),JSON.stringify({schema:1,error:error.stack||String(error)},null,2)+'\n',{flag:'wx'});process.exitCode=1;});
