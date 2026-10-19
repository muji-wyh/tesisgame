# Approved Professional audio delivery

The user's `tesis-iter-2` reply at 2026-10-16 09:26:44 Asia/Shanghai approved the
displayed **aisle** and **cash register** recordings. Its assistant turn failed
with an API decoding error, so the earlier pending-feedback status was stale.
The approval is attached to exact source bytes and the original question/reply
identifiers in `docs/assets/sources/professional-retail-ava/listening-approval-2026-10-16.json`.
The original acquisition record and the source MP3/WAV files remain unchanged.

| Recording | SHA-256 | Production source |
| --- | --- | --- |
| aisle | `3674da249cd440ce5804ffe3a1dac6892d7b6a7c642d721a8e4fa2ef1da639c3` | Exact previously presented WAV |
| cash register | `0f883c09be9a86be9f30e444953d001d3a385ba71034e60ceb4181fc0b9aa763` | Exact previously presented WAV |

Each is 82,598 bytes, with 41,277 PCM16 mono frames at 22050 Hz and a duration of
1.871972789 seconds. There was no synthesis, trimming, gain change, pitch change,
or other processing during integration. The native raw loader decoded both
production paths, checked their metadata and hashes, and exercised round pinning,
repeat selection, inactive trimming and final release: **29 checks passed**.
Both clips together occupy 165,108 decoded bytes; final cache bytes/resources and
leases are zero. A deliberately changed sample fails the hash check.

The exact audio/provenance tests pass **2/2**. The candidate-only Professional
generation tests pass **4/4**, and the original Growth voice-generator tests pass
**17/17**. A focused Retail/draft content run passed **15 substantive tests**.
The original combined audio test run had one test-harness error: a schema name
included the suffix twice. Its follow-up exposed a null-morphology assumption in
the same test. Both harness assumptions were corrected, preserving the actual
content gates, and the exact-audio suite passed 2/2. No product failure was hidden.

The new candidate tool verifies acquired hashes and exact voice parameters,
requires language-reviewed term text, and keeps every new recording pending
listening review. An approved-senses-only preparation retained both integrated
clips and requested zero recordings. Network acquisition was not exercised in
this integration; the earlier successful pinned-client acquisition is preserved
in the original receipt.

Only the two audio descriptors changed. The integration receipt records their
old/new audio metadata and hashes of all other fields. The original 1,888 Growth
and prompt recordings and all seven sequential collection notes are preserved.
No curriculum manifest was marked ready and no production deployment occurred.
The native manifest is an audio delivery review, not a complete module fixture.
User approval establishes the two source clips' pronunciation and voice fit;
these checks do not claim agent listening, physical-device playback, or in-game
acoustic-mix verification.

## Four-recording delivery addendum

The user subsequently approved the exact displayed **shopping cart** and
**shopping basket** candidates. Their approval is bound to the original
question/reply and WAV hashes in
`docs/assets/sources/professional-retail-ava/cart-basket/listening-approval-2026-10-16.json`.
The original acquisition receipts remain pending historical records; the later
approval addendum supplies the decision without rewriting that history.

| Recording | WAV SHA-256 |
| --- | --- |
| shopping cart | `150246ccfdd916301a660583fc5e552a7fb585fb4ccb2317b9ed4a40ebd1da56` |
| shopping basket | `aac69f3394f2acd4486e68e32213e328849c204f0ddced680f56011c65ce4e12` |

The R05 native run exercised all four exact production recordings and passed
**53 checks with zero failures**. Hash verification, raw WAV decoding, round
pinning, cache reuse, inactive trimming and release cover four resources and
330,216 decoded bytes. Final cache bytes, resources and leases are zero. Log:
`build/professional-english/continuation-native-audio-r05.log` (SHA-256
`e28acdaedc14e0898c3f04ca1fad61d09fdb0f82e64b58437df7e267e58a04fc`).
This adds native delivery evidence to the exact user listening approvals; it
does not establish physical-device playback or in-game acoustic balance.

R05 as a whole remains failed: its Node run passed 176/177 because the new
retail-media test was missing from the central test-plan registration. The
native audio success is a scoped result, not a passing combined-validation
claim. The registration was corrected and the runner suite passed 4/4; the
failed R05 receipt and logs remain unchanged.

## Six-recording delivery addendum

The user directly approved the presented pallet and shelf WAVs. Exact hashes,
the original question identity and the translated reply are retained in
`docs/assets/sources/professional-retail-ava/pallet-shelf/listening-approval-2026-10-16.json`.
Integration copied those exact files and preserved all 1,899 prior recordings.

The R08 native delivery run passed **75 checks with zero failures** across
aisle, cash register, shopping cart, shopping basket, pallet and shelf. The
production raw loader checked hashes, complete PCM16 mono 22050 Hz decoding,
durations, six-resource dependency admission, round leases, repeated selection,
inactive trimming and final release. Total decoded residency was 495,324 bytes;
final resources, resident bytes and leases were zero. The log SHA-256 is
`3c1d741c9503af6825eeef96efed14f223289676dab7639a3e86cbd63054c540` at
`build/professional-english/continuation-native-audio-r08.log`.

Combined R08 validation passed 185/185 Node tests and 914/0 native morphology
checks with zero skips and unchanged measured inputs/registry. R07's identical
75/0 audio result is retained alongside its overall failed status due to two
morphology test-expectation errors. Neither run supplies new listening approval,
physical-device playback evidence or an in-game acoustic-mix review. All 200
curriculum modules remain draft.

## Eight-recording delivery addendum

The user directly approved the presented shopping bag and gift wrap WAVs. Their
exact approval is recorded in
`docs/assets/sources/professional-retail-ava/bag-wrap/listening-approval-2026-10-16.json`.
Integration preserved all 1,901 previous audio files and changed only the two
audio descriptors and obsolete pending-audio note clauses. The original pending
acquisition receipts remain historical evidence.

The focused eight-recording native run passed **97 checks with zero failures**.
The production raw loader verified exact hashes, complete PCM16 mono 22050 Hz
decoding and durations, dependency admission, round leases, reuse, inactive
trimming and final release. Total decoded residency was 660,432 bytes; final
resources, resident bytes and leases were zero. The registry stayed at
`d1caec76221920c17e1ba8fb14cb612fb9102e89ba2302610255b8b6e9e163bb` and
all measured inputs were unchanged.

Evidence: `build/professional-english/retail-audio-review/bag-wrap-acquired-r01/native-delivery-r01.json`,
raw SHA-256 `6b658c3efb4a79ead54687a99767fa4903de37001da4f4ba1d99996b468b11fc`;
log SHA-256 `17424f62e99e447e35c75601b8fc0f3d1080aa8acb3ea211f7406769a6d0ecf6`.
This focused delivery result does not rewrite the historical R08 combined run or
establish physical-device playback, acoustic-mix approval or module readiness.

## Counter and checkout: exact human approval and R14 delivery

The direct reply to `call_fBfAoFlUyKmhWveN2mNUORiZ` approved both presented WAVs.
Their guarded integration and test update journals committed successfully. All
1,903 prior recordings and the collection source master remain exact.

R14 passed 192/192 Node tests, 1,210/0 native morphology checks and 119/0 native
approved-audio checks, without skips or changed measured inputs/registry. The
ten immutable WAVs total 825,540 decoded PCM bytes. The actual loader verifies
bytes, decode, dependency bounds, leases, cache reuse, pinned survival and
zero-resource/byte/lease teardown. It does not play the full game acoustic mix.

R13 is retained as a failed 191/192 Node result despite successful 1,210/0
morphology and 119/0 audio checks. A new test had hardcoded pending for both
domain fields; checkout already had not_required. The correction requires full
original review-object equality plus exact per-sense gate values, with no
production correction. Correction evidence:
`build/professional-english/counter-checkout-test-correction-r01.json`.

R14 receipt: `build/professional-english/continuation-validation-r14.json`, raw
SHA256 `826a90b1aa354f16d484f7bd88c85b200fdec6ee0146d4ffa875bcc9c634877d`.
Registry JSON SHA256: `af2c950cf3c7d2d22e487817526d464e96956ac2c7df40bd890783bd3dd73bdf`.
All curriculum modules remain draft.

## Twelve-recording delivery addendum

The recovered direct human reply in `tesis-iter-4`, turn
`01a144de-9fa7-7b03-808c-2d0aa3cfc73c`, approved both exact card reader and barcode
samples presented by `call_7xvby6MgGR1DNVzcwIkhjACI`. The reply is retained in
`docs/assets/sources/professional-retail-ava/card-reader-barcode/listening-approval-2026-10-16.json`.
Both approved WAVs were copied without resynthesis or processing. Original pending
acquisition and listening receipts remain unchanged.

The transaction committed against the successful R27 baseline, which already
included eight images and ten recordings. Only the two audio descriptors and
their obsolete pending-audio clauses changed. All 1,905 earlier audio files,
the collection source master and eight integrated images were hash-verified and
preserved. The registry moved from
`177e2b31352da65df8412e2f681fcfbc0fbf2ba6ed825a9ada749cbeb823ab05` to
`58acf6fbf52810707fa5e57dadc23e42b73b2cf7171144a9cdbf2650258c0d50`.

The focused audio/media Node run passed **22/22 tests**, with no skips or failures.
The actual native loader passed **141 checks with zero failures** for all twelve
recordings. Checks cover hashes and altered-byte rejection, complete PCM16 mono
22050 Hz decoding, durations, dependency admission, round pinning, reuse,
inactive trimming and release. Twelve clips total 990,648 decoded PCM bytes;
final resident resources, bytes and leases are zero. Native measured inputs and
the registry were unchanged.

Evidence under `build/professional-english/retail-audio-review/card-reader-barcode-acquired-r01/`:

- `integration-receipt-r01.json`, raw SHA256
  `c3408e918622beabc33bb09dd4cddf0ba5df2ab722b76ee93e686ee8cfdf658c`.
- `focused-node-r01.log`, raw SHA256
  `9a8009156649acb3fb2124cec62c90a69ca728e6a9f2419d93469de755658f6d`.
- `native-delivery-r01.json`, raw SHA256
  `809dca51fe175c706fe8403d465c98b7812b22123dc614a334c354c35b8a13b1`.
- `native-delivery-r01.log`, raw SHA256
  `334e8ab10b0870d68f4df789af320c1402efb89517f2666ad72f730c7c3c49a6`.

This native result supplies the subsequent delivery verification explicitly
pending in the immutable integration record. It does not extend old ten-recording
receipts or claim physical-device playback, in-game acoustic review or module
readiness. Card reader still needs an accepted image. Every curriculum module
remains draft, with its language, domain and morphology gates preserved.

The subsequent combined R28 run remains preserved as **failed: 227/228 Node
tests**, alongside successful **2,837/0 morphology** and **141/0 audio** native
checks. Inputs and registry were unchanged. One historical Retail04 test still
compared its protected card-reader snapshot directly to current data and missed
the later approved audio change. The narrow correction routes that comparison
through the existing exact audio-patch restoration helper, which requires full
current-entry equality before restoring the historical entry. Unrelated drift
still fails. Production data needed no correction. The affected test then passed
**1/1**, with no skips, in
`build/professional-english/retail-audio-review/card-reader-barcode-acquired-r01/historical-test-correction-r01.json`.
The immutable R28 receipt raw SHA256 is
`d0117126e6eb3775e24895c98f3d212e0ad88aa759d2cd93e7fcdd5eaecde524`.
