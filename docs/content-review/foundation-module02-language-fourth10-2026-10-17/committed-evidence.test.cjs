'use strict';
// Postcommit-only persisted evidence check. It must fail before a committed journal exists.
const test=require('node:test'),assert=require('node:assert/strict'),evidence=require('./evidence-contract.cjs');
test('Foundation02 fourth-ten persisted evidence binds scoped validation, retained sources and committed journal',()=>{
  const result=evidence.verifyPersisted();assert.equal(result.ok,true);assert.equal(result.current_inputs,864);assert.equal(result.additional_candidate_inputs,0);
});
