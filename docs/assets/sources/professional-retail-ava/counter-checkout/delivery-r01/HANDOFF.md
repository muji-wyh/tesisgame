# Exact approved counter and checkout audio

This scratch package binds the exact two WAVs presented in `listening-request.json` and approved by the direct human reply recorded separately in `human-approval-r01.json`. The historical acquisition, technical QA and listening-request files are unchanged. The WAVs are never regenerated or processed by this package. Production integration, baseline binding, shared test edits and native/test execution remain root-owned.

The approval record has SHA256 `d9487d9a2a2a93805fa597f87dcf775f1cebae88c89fc97c13de90acbece2e82` and refers to question call `call_fBfAoFlUyKmhWveN2mNUORiZ`. Its English response is "Both are acceptable". Technical QA has SHA256 `5300530a5630b15ca27921f488f123ef228fab38d89cc9ad982e3f71460b608b`. The listening request has SHA256 `10cdbe11ca4e9a0ae1122dc5ae2acffc69228db3d68bc7245988186667359bab`.

| Sense | Approved WAV SHA256 | Bytes / PCM bytes |
| --- | --- | --- |
| `counter.service-surface.n` | `685b544dbb353f3a1f3fb999fbe3f541cb94874d0e4543ad0cba774c39fd4bc3` | 82,598 / 82,554 |
| `checkout.payment-area.n` | `39df6ba3406a891283f99379ca8526d93fc8f3279b571134c0213dd824282224` | 82,598 / 82,554 |

Each recording is complete PCM16 mono at 22,050 Hz, 41,277 frames, with the exact `ava-sweet` profile: `en-US-AvaNeural`, rate `-15%`, pitch `+8Hz`, volume `+0%`, no effects or trimming. The existing QA proves complete PCM equality to a no-effects source MP3 decode. That historical technical finding is separate from the later human listening approval.

Only `media.audio` and one exact pending-audio note clause change in each entry. Counter's accepted image and note remain intact except that the remaining audio clause becomes approved/integrated. Checkout retains pending picture suitability and word-image production. All other lexical, image, morphology, language, domain and curriculum fields stay exact. All 1,903 prior recordings are hashed before binding and again during integration verification; the collection source master is checked separately.

## Root binding and integration

After reviewing the frozen preparation receipt, select an exact successful current combined validation and the successful counter production-image delivery receipt. The binder checks their complete unchanged input and registry evidence. It writes only new scratch preimages and binding receipts.

```powershell
node build/professional-english/retail-audio-review/counter-checkout-acquired-r01/delivery-r01/bind-current-baseline.cjs --preparation-sha256 EXACT_PREPARATION_SHA256 --validation-path build/professional-english/continuation-validation-rNN.json --validation-sha256 EXACT_VALIDATION_SHA256 --counter-delivery-path build/professional-english/retail-term-art-review/counter-r01/production-delivery-rNN/production-check-rNN.json --counter-delivery-sha256 EXACT_COUNTER_DELIVERY_SHA256
node build/professional-english/retail-audio-review/counter-checkout-acquired-r01/delivery-r01/integrate-reviewed.cjs --preimages-sha256 EXACT_PREIMAGES_SHA256
```

Review the read-only plan, then add `--integrate` for the same explicit preimages hash. The shared reviewed helper and plan adapter are copied byte-identically; their source and prior fault-test receipts are in `helper-origin.json`. The transaction uses `build/professional-english/transactions/counter-checkout-audio-r01`, under the same central cooperative lock as the image and morphology integrations.

Every retained source/evidence file, both production WAVs, the raw lexeme replacement, listening approval, provenance and integration receipt participate in one guarded transaction. Identical preexisting immutable files become no-ops. Differing preexisting immutable bytes are rejected. The helper stages exact outputs and raw backups, persists its prepared journal, installs outputs, and verifies all output bytes, complete registry/audit, Professional JSON membership, validated inputs and all earlier recordings before commit. The receipt alone is not completion; its journal must be committed.

On a write or verification exception, rollback restores the exact original raw lexeme bytes and removes only proved-owned new outputs. An interrupted process requires explicit inspected rollback:

```powershell
node build/professional-english/retail-audio-review/counter-checkout-acquired-r01/delivery-r01/integrate-reviewed.cjs --preimages-sha256 EXACT_PREIMAGES_SHA256 --recover
```

Recovery reconstructs the trusted plan from the pinned raw preimage and immutable sources before parsing any live registry. It passes the expected plan hash to the helper and checks the restored baseline afterward. Unowned changed bytes are preserved and require manual resolution. Existing identical files and existing directories are preserved. A committed journal is a no-op. This is process-interruption recovery, not multi-file atomic visibility or power-loss durability. Never overwrite a failed or completed journal.

## Proposed persisted test update

The separate `update-persisted-tests.cjs` is read-only by default and requires `--preimages-sha256` plus `--integration-receipt-sha256`. It binds test preimages to the successful validation selected by the audio binder. It requires a committed audio journal and exact output bytes before creating a test plan. Add `--apply` only after reviewing that plan. Explicit recovery also requires `--recover --transaction-plan-sha256 EXACT_REPORTED_TEST_PLAN_SHA256`. Its transaction is `build/professional-english/transactions/counter-checkout-audio-tests-r01`.

Four shared files are affected:

- `tests/professional-content.test.cjs`: append the exact audio reversal after counter image history; audio count 8 to 10.
- `tests/professional-retail-morphology.test.cjs`: append the audio reversal for first-through-fourth historical snapshots. For both fifth10 related-entry and first-forty snapshot protections, reverse the exact counter/checkout audio first, then the counter image. Every reversal first requires full equality to its patch's after-entry.
- `tests/professional-retail-media.test.cjs`: reverse the exact later counter audio before the older counter image assertions, add exact presented-pair/human-approval/protected-field checks, preserve all 1,903 previous recordings, and change current audio count to ten. Existing image counts and earlier media assertions remain.
- `tests/godot/professional_approved_audio_tests.gd`: add the new approval provenance and cover all ten WAVs, exact total 825,540 PCM bytes, bounded cache reuse and lease teardown. Native morphology stays unchanged.

The test transaction covers all four raw file replacements and its receipt together. A failed verification or explicit interrupted recovery restores the exact validation-era test bytes and removes only the owned receipt. It does not roll back the already committed audio transaction. A committed test transaction is a no-op on recovery. No updater runs tests. Root must execute the updated Node/native suites and the combined post-integration validation afterward.
