'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const {loadProfessionalContent, schemaErrors, morphologyErrors} = require('../tools/validate-professional-content.cjs');

const root = path.resolve(__dirname, '..');
const source = loadProfessionalContent(root);
const revision = 'professional-v2-foundation02-held-six-r01';
const oldIds = ['collect.gather.v', 'notify.inform.v', 'verify.establish-accuracy.v'];
const newIds = ['collect.bring-together.v', 'inform.give-information.v', 'ensure.make-certain.v'];
const selected = id => {
  const rows = source.lexemes.filter(entry => entry.id === id);
  assert.equal(rows.length, 1, id + ': exactly one active canonical entry');
  return rows[0];
};

test('held-six current manifests coordinate sixty substitutions without retaining retired active objectives', () => {
  assert.equal(source.catalog.curriculum_revision, revision);
  assert.equal(source.courses.length, 20);
  assert.equal(source.lexemes.length, 4939);
  assert.equal(source.expressions.length, 1620);
  assert.equal(new Set(source.lexemes.map(entry => entry.id)).size, source.lexemes.length);
  for (const id of oldIds) {
    assert.equal(source.lexemes.some(entry => entry.id === id), false);
    assert.equal(source.expressions.some(entry => entry.focus_lexeme_ids.includes(id)), false);
  }
  for (const course of source.courses) {
    assert.equal(course.curriculum_revision, revision);
    assert.equal(course.modules.length, 10);
    for (const module of course.modules) {
      assert.equal(module.requirements_revision, revision);
      assert.equal(module.status, 'draft', 'Synthetic ready fixtures do not promote actual modules');
      assert.equal(module.lexeme_ids.length, 50);
      assert.equal(module.expression_ids.length, 10);
      for (const old of oldIds) assert.equal(module.lexeme_ids.includes(old), false);
    }
    const module = course.modules.find(row => row.id === 'module02');
    assert.deepEqual([13, 18, 27].map(index => module.lexeme_ids[index]), newIds);
    assert.equal(new Set(course.modules.flatMap(row => row.lexeme_ids)).size, 500);
    assert.equal(new Set(course.modules.flatMap(row => row.expression_ids)).size, 100);
  }
});

test('gathering request preserves the exact complete sentence, eighteen token positions and fresh assessed focus', () => {
  const rows = source.expressions.filter(entry => entry.id === 'expr.foundation.module02.08');
  assert.equal(rows.length, 1);
  const expression = rows[0];
  assert.equal(expression.text, 'Could you assist me while I collect one form from each team and return the borrowed key?');
  assert.equal(expression.meaning, 'Ask a colleague to help gather forms from several teams and give a borrowed key back.');
  assert.equal(expression.context, 'A worker gathers one fictional workshop form from each of three teams and gives a borrowed meeting-room key back to reception.');
  assert.deepEqual(expression.focus_lexeme_ids, ['assist.help.v', newIds[0], 'return.send-back.v']);
  const expected = ['Could', 'you', 'assist', 'me', 'while', 'I', 'collect', 'one', 'form', 'from', 'each', 'team', 'and', 'return', 'the', 'borrowed', 'key', '?'];
  assert.deepEqual(expression.tokens.map(token => token.text), expected);
  let end = 0;
  for (const [index, token] of expression.tokens.entries()) {
    assert.equal(token.index, index);
    assert.ok(token.start >= end && token.end > token.start);
    assert.equal(expression.text.slice(end, token.start).trim(), '');
    assert.equal(expression.text.slice(token.start, token.end), expected[index]);
    end = token.end;
  }
  assert.equal(expression.text.slice(end), '');
  assert.deepEqual(schemaErrors(expression, 'expression'), []);
});

test('canonical ensure composition coexists with accepted insure; atomic collect and inform remain intact', () => {
  for (const id of newIds) {
    const entry = selected(id);
    assert.deepEqual(schemaErrors(entry, 'lexeme'), []);
    assert.deepEqual(morphologyErrors(entry.morphology, entry), []);
    assert.equal(entry.morphology.review.status, 'reviewed');
  }
  const ensure = selected(newIds[2]);
  assert.deepEqual(ensure.accepted_forms, ['ensure', 'insure']);
  assert.ok(ensure.editorial_notes.includes('Insure is an accepted alternative especially in North American English for this outcome sense. Financial insurance is a separate sense.'));
  assert.equal(ensure.morphology.text, 'ensure');
  assert.equal(ensure.morphology.id, 'ensure.make-certain.v.analysis.v1');
  assert.deepEqual(ensure.morphology.parts.map(part => [part.canonical_id, part.type, part.surface]), [
    ['english.affix.en.causative', 'prefix', 'en'], ['english.stem.sure.certain', 'stem', 'sure']
  ]);
  assert.deepEqual(ensure.morphology.nodes, [{id: 'n1', left: 'p1', right: 'p2', surface: 'ensure', rule: 'prefix_attachment', break_offsets: []}]);
  assert.deepEqual(ensure.morphology.roots, ['n1']);
  for (const [index, family] of ['english.atomic.collect.gather', 'english.atomic.inform.give-information'].entries()) {
    const entry = selected(newIds[index]);
    assert.equal(entry.morphology.kind, 'atomic');
    assert.equal(entry.morphology.parts.length, 1);
    assert.deepEqual(entry.morphology.nodes, []);
    assert.equal(entry.morphology.parts[0].canonical_id, family);
    assert.equal(entry.morphology.parts[0].surface, entry.text);
  }
});

test('accepted language and morphology do not bypass actual media, specialist or module gates', () => {
  for (const id of [...newIds, 'postpone.delay-until-later.v', 'unsafe.presenting-danger.adj', 'hazard.possible-harm.n']) {
    const entry = selected(id);
    assert.equal(entry.review.language, 'reviewed');
    for (const kind of ['image', 'audio']) {
      const media = entry.media[kind];
      assert.equal(media.status, 'pending');
      assert.equal(media.review.status, 'pending');
      assert.equal(media.path, null);
      assert.equal(media.sha256, null);
      assert.equal(media.acquisition_status, 'not_started');
    }
    assert.equal(entry.media.audio.voice, 'ava-sweet');
    assert.deepEqual(entry.media.audio.voice_settings, {voice: 'en-US-AvaNeural', rate: '-15%', pitch: '+8Hz', volume: '+0%', postprocessing: false});
  }
  for (const id of ['unsafe.presenting-danger.adj', 'hazard.possible-harm.n']) assert.equal(selected(id).review.domain, 'pending');
  const ensure = selected(newIds[2]);
  assert.equal(ensure.media.image.picture_suitable, false);
  assert.deepEqual(ensure.practice_modes, ['word_jelly', 'phrase']);
  for (const id of ['expr.foundation.module02.02', 'expr.foundation.module02.04', 'expr.foundation.module02.08']) {
    const expression = source.expressions.find(entry => entry.id === id);
    assert.equal(expression.media.audio.status, 'pending');
    assert.equal(expression.media.audio.path, null);
  }
});
