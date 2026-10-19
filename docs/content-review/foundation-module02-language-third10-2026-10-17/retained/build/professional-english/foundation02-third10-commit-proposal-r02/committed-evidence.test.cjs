'use strict';
// This is a postcommit-only persisted test. It must fail before a committed journal exists.
const test=require('node:test');
const assert=require('node:assert/strict');
const evidence=require('./evidence-contract.cjs');
test('Foundation02 third-ten persisted evidence binds current validation, retained sources and committed journal',()=>{
  const result=evidence.verifyPersisted();
  assert.equal(result.ok,true);
  assert.equal(result.current_inputs,680);
});
