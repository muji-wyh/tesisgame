# Narrow shared-test delta for final rebase

This plan identifies semantic edits, not fixed line numbers or byte patches. Actual sources and source hashes must be read after successful fourth-ten delivery. Do not edit these production/shared tests while preparing this proposal.

## Strict historical reversal

Load the new finalized bag provenance as a separate `shoppingBagImageRecord`. Add the following equivalent helper in each affected shared suite, with local naming consistent with that suite:

```js
function beforeShoppingBagImage(entry) {
  const patch = shoppingBagImageRecord.patches.find(item => item.id === entry.id);
  if (!patch) return entry;
  assert.equal(patch.id, 'shopping-bag.goods-carrier.n');
  assert.deepEqual(entry, patch.after, entry.id + ': exact later shopping-bag image and three note clauses');
  return structuredClone(patch.before);
}
```

The focused provenance test must separately require exactly one patch, the exact before/after hashes and the literal three-note replacement operation. This helper accepts only the exact new after-object. Do not make it tolerate the historical before-object, unknown intermediates or selectively copied image fields; those shortcuts would hide drift. An unrelated ID passes through unchanged. Ensure it executes once per relevant historical path.

In all three files, `beforeFifth10` currently asserts equality against the historical Retail03 fifth-ten morphology afterimage. Add the new image reversal at its start, before looking up/asserting that historical patch. This makes the existing `beforeRetail03Media` / `beforeRetailMedia` pipelines and the media suite's bag-wrap audio loop work in correct chronological order. Do not append this new image to an older-media array that runs after `beforeFifth10`; that would reverse it too late.

The morphology suite's `Fifth ten preserve exact reviewed candidates, approved audio and all unrelated release gates` test currently compares a direct live entry with each historical `patch.after`. Its local `entry` must be `beforeShoppingBagImage(liveEntry)` before that equality and protected-field check. The unchanged live graph remains separately verifiable. `beforeCounterImage`, used for historical related-entry and protected-first40 snapshots, also needs the strict image reversal at its external entry point if its current call graph still receives live entries. Inspect every call during rebase to prevent a second reversal of an already-restored bag. Keep all fourth-ten donor-snapshot/source-history changes as delivered, including any explicitly permitted duplicate historical snapshots.

## Live counts versus historical counts

- `professional-content.test.cjs`: update the live `result.summary.integrated_word_images` expectation from eight to nine when the installation baseline is still eight. Preserve actual fourth-ten reviewed counts and every other expectation.
- `professional-retail-media.test.cjs`: update the live filtered integrated-image count from eight to nine. The live approved recording count stays twelve.
- Keep the historical `cardReaderBarcodeAudio.baseline_summary.integrated_word_images` value of eight and its historical audio count of ten. Never global-replace counts, old snapshots or receipts.
- Do not infer a reviewed curriculum/module/theme count increase from this image change. Do not change warning-count expectations without observing the real new audit.

## Focused persisted assertions

Add focused cases to the media suite (or an independently reviewed dedicated file only if root chooses an explicit expanded write set) that prove:

1. The provenance has one bag patch; its afterimage equals the actual live bag. The raw new provenance and accepted proposal references match their frozen transaction pins. `before_sha256`, `after_sha256` and protected projection match actual JSON objects. Replacing exactly the three specified single-occurrence clauses reproduces the after-note; arbitrary note changes fail.
2. Only `media.image` and the authorized note text differ. Definition, example, A2 provisional estimate, `['shopping bag']`, general region, five practice modes, all review/reference fields, approved audio descriptor/settings/hash and the authored shop + activity `-ing` + Growth bag graph stay exact. No `carrier bag`, `phrase` or unreviewed confusable identity appears.
3. Image path, content hash, CC0 creator/source fields, accepted brief and exact three adaptations match `image-descriptor.proposed.json`. PNG signature/header/dimensions, encoded length and exact hash match `resource.json`; decoded accounting is width * height * 8. Source original and preview are not substituted. No additional transform or animation is claimed.
4. The exact accepted visual-review file is pinned and still says candidate image/brief accepted but production not integrated. The original source record still has its historical pending/false acceptance fields; original brief/mismatch and gift-bag ambiguity are retained in new provenance. Static review is not relabeled as participant, full-board/browser or audio acceptance.
5. All eight earlier image descriptors and bytes and all twelve approved audio descriptors and bytes match the media observation rechecked against the actual final baseline. Existing suites continue to verify the original approval records and sequential collection clips; do not replace those checks with a count-only assertion.
6. All non-bag lexical objects, expressions, modules, sources, Growth/runtime files and historical failure/review artifacts remain exact under the final transaction's protected inventory. Module status, manifests and revisions remain unchanged. The actual auditor still rejects incomplete module activation.
7. Strict reversal rejects a changed image hash/path, note, brief, audio field, accepted form or morphology graph; it restores only the exact new accepted after-object to the exact historical before-object. Keep the ordinary non-bag passthrough. These meaningful negative cases protect provenance history, not an alternate permissive implementation.

## Dispatch boundary

No tests are dispatched by this proposal. After independent review and installation, root runs the fresh persisted Node/content/media checks required by the actual transaction. Existing native candidate/lifecycle evidence is retained and not replayed; presentation/runtime code and audio are unchanged. Any failed future check must be recorded as a new immutable result before an affected correction is prepared.
