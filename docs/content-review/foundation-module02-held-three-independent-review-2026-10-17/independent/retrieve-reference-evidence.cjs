'use strict';
// Independent reference consultation only. Never imports project modules or writes production content.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../..');
assert.equal(root.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const sourceBefore = sha(fs.readFileSync(__filename));
const save = (name, value) => fs.writeFileSync(path.join(__dirname, name), JSON.stringify(value, null, 2) + '\n', {flag: 'wx'});
const requests = [
  {id:'O-postpone',url:'https://www.oxfordlearnersdictionaries.com/definition/english/postpone',sense:'postpone_sng_1'},
  {id:'O-unsafe',url:'https://www.oxfordlearnersdictionaries.com/definition/english/unsafe',sense:'unsafe_sng_1'},
  {id:'O-hazard',url:'https://www.oxfordlearnersdictionaries.com/definition/english/hazard_1',sense:'hazard_sng_1'},
  {id:'P-CSV',url:'https://raw.githubusercontent.com/openlanguageprofiles/olp-en-cefrj/master/cefrj-vocabulary-profile-1.5.csv'},
  {id:'P-TERMS',url:'https://raw.githubusercontent.com/openlanguageprofiles/olp-en-cefrj/master/README.md'},
  {id:'P-METHOD',url:'https://www.cefr-j.org/download.html'},
  {id:'L-HAZARD',url:'https://www.teachingenglish.org.uk/teaching-resources/teaching-secondary/uk-history-and-literature/first-world-war/joining-british'}
];
save('reference-retrieval-start.json',{schema:1,recorded_at:new Date().toISOString(),source_sha256:sourceBefore,requests,
  scope:'Fresh independent HTTP reference consultations. Only hashes, response metadata, three selected sense attributes and three English profile rows are retained. No full remote text or media is retained.'});
(async()=>{
  const results=[];
  for(const request of requests){
    const started=new Date().toISOString();
    try{
      const response=await fetch(request.url,{signal:AbortSignal.timeout(20000)});
      const body=Buffer.from(await response.arrayBuffer()),text=body.toString('utf8');
      const row={id:request.id,url:request.url,started_at:started,finished_at:new Date().toISOString(),final_url:response.url,
        http_status:response.status,ok:response.ok,bytes:body.length,raw_body_sha256:sha(body),content_type:response.headers.get('content-type'),
        complete_source_retained:false,media_acquired:false};
      if(response.ok&&request.sense){
        const tag=[...text.matchAll(/<li\b[^>]*>/g)].map(match=>match[0]).find(value=>value.includes('id="'+request.sense+'"'));
        assert(tag,'Selected sense tag not found: '+request.id);
        const attribute=name=>tag.match(new RegExp('(?:^|\\s)'+name+'="([^"]*)"'))?.[1]??null;
        row.literal_selected_attributes={element_id:attribute('id'),sense_number:attribute('sensenum'),cefr:attribute('cefr'),fkcefr:attribute('fkcefr')};
      }
      if(response.ok&&request.id==='P-CSV'){
        const lines=text.split(/\r?\n/);
        row.selected_rows=['postpone','unsafe','hazard'].map(term=>({term,matches:lines.flatMap((line,index)=>line.split(',')[0]===term?[{line_number_1_based:index+1,csv:line}]:[])}));
        row.version='1.5';row.selected_sense_ids_present=false;row.productive_mastery_certification=false;
      }
      results.push(row);
    }catch(error){results.push({id:request.id,url:request.url,started_at:started,finished_at:new Date().toISOString(),ok:false,error:String(error),complete_source_retained:false});}
  }
  const sourceAfter=sha(fs.readFileSync(__filename));
  save('fresh-independent-http.json',{schema:1,recorded_at:new Date().toISOString(),reviewer:'Codex runtime_recovery independent AI language reviewer',
    source_before_sha256:sourceBefore,source_after_sha256:sourceAfter,source_unchanged:sourceBefore===sourceAfter,
    results,production_mutated:false,tests_dispatched:false,native_dispatched:false,serializer_dispatched:false});
  console.log(JSON.stringify({requests:results.length,successful:results.filter(row=>row.ok).length,source_unchanged:sourceBefore===sourceAfter,
    receipt_sha256:sha(fs.readFileSync(path.join(__dirname,'fresh-independent-http.json')))}));
})().catch(error=>{console.error(error);process.exitCode=1;});
