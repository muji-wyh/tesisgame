# Retail pronunciation acquisition and approval

Twelve exact Ava Sweet recordings are user-approved and integrated: **aisle**,
**cash register**, **shopping cart**, **shopping basket**, **pallet**,
**shelf**, **shopping bag**, **gift wrap**, **counter**, **checkout**, **card reader**
and **barcode**. The first pair's
pronunciation, rate and voice quality were approved
on 2026-10-16 at 09:26:44 Asia/Shanghai. The reply was recovered from
`tesis-iter-2` after its processing turn failed; no further approval was needed.
The complete source MP3s, decoded WAVs, client provenance, settings and hashes are
retained in [the acquisition record](sources/professional-retail-ava/acquisition.json).
That original pre-approval record remains unchanged. Its pending-review fields
are superseded, for these exact two clips only, by the
[human listening approval](sources/professional-retail-ava/listening-approval-2026-10-16.json).

## Client recovery

The first attempt used edge-tts 7.2.8. Both terms failed all three attempts with
`WSServerHandshakeError`; no recordings were obtained. That attempt remains in
`build/professional-english/retail-audio-review/attempt-receipt.json`.

The [upstream issue owner](https://github.com/rany2/edge-tts/issues/490) reports
resolution in 7.3.0. The [7.3.1 release](https://github.com/rany2/edge-tts/releases/tag/7.3.1)
adds a locale-dependent date parsing fix. A direct official PyPI index query
confirmed the release; the configured package index had reported only 7.2.8.
Downloads from `files.pythonhosted.org` failed TLS negotiation with both Python
and PowerShell. The official GitHub 7.3.1 tag archive was successfully acquired
using normal TLS, then built and installed in an isolated development environment.
No certificate-validation bypass, copied service token, or proxy was used.

The new client acquired both candidates successfully. The approved profile remains
`en-US-AvaNeural`, rate `-15%`, pitch `+8Hz`, volume `+0%`. FFmpeg only decodes and
resamples the original MP3 to the existing PCM16 mono 22050 Hz WAV format. No
effects, clipping adjustment, silence removal, or other creative processing occur.
Microsoft service terms apply; the client library license is not a speech license.

## Verification and limits

- Both complete WAVs pass the existing format and audible-sample checks, contain
  zero clipped samples, and have retained source and output hashes.
- The voice tooling pins 7.3.1 and records each recording's acquisition client when
  extending an older catalog. The focused generator suite passes 17/17, including
  mixed-version retention and rejection of unknown provider/client metadata.
- All 1,888 existing Growth/prompt recordings match their historical manifest
  hashes. Missing-only validation requested and converted zero files; the original
  7.2.8 provenance manifest is byte-identical.
- The original session could not consume audio input. The user listened to the
  two displayed clips and approved them; the recovered question/reply identifiers,
  English translations and exact sample hashes are retained in the approval
  addendum. No agent listening or in-game acoustic-mix review is claimed.

The approved bytes were copied without regeneration or processing to immutable
`professional-media/<sha256>.wav` paths. Only `media.audio` for
`aisle.passage.n` and `cash-register.sales-device.n` changed. The integration
receipt is `data/professional/provenance/retail-approved-audio-2026-10-16.json`.
All other language, domain, morphology, image, course and theme gates were
preserved. Every Retail module remains in preparation; these two clips do not
make a module playable or publish it.

Native delivery review passed 29 checks using the real production files, including
SHA-256 verification, complete PCM16 mono 22050 Hz decoding, duration, cache
leases, repeated selection and release. The two clips consume 165,196 encoded
bytes and 165,108 decoded PCM bytes; cache residency and leases return to zero.
This is technical delivery evidence, separate from the user's listening review.
See [the delivery QA](../qa/2026-10-16-approved-professional-audio.md).

## Shopping cart and shopping basket approval

Shopping cart and shopping basket were acquired on 2026-10-16 in
`build/professional-english/retail-audio-review/cart-basket-acquired-r01/`.
Their exact WAVs were presented for user listening review in the continuation
chat. The user directly answered that both were acceptable. The English
translation, original question identity and exact submitted hashes are retained
in [the new listening approval](sources/professional-retail-ava/cart-basket/listening-approval-2026-10-16.json).
Both exact WAVs are now integrated, without synthesis or processing during the
copy. The original pending acquisition receipts remain immutable.
The earlier prepared-only `cart-basket/` manifest remains unchanged.

The immutable `technical-qa-r01.json` reports 49 passing checks, no failures,
PCM16 mono 22050 Hz, 1.871973 seconds per sample, and zero clipped samples.
Each full PCM stream equals an independent decode/resample of its retained
source MP3 without effects or trimming. All 1,888 historical recordings, the
seven sequential collection sounds and both integrated Professional recordings
match their established inventories. The registry and all audio metadata stayed
unchanged through acquisition and QA. Technical checks do not establish listening
or pronunciation approval.

| Approved recording | WAV SHA-256 |
| --- | --- |
| shopping cart | `150246ccfdd916301a660583fc5e552a7fb585fb4ccb2317b9ed4a40ebd1da56` |
| shopping basket | `aac69f3394f2acd4486e68e32213e328849c204f0ddced680f56011c65ce4e12` |

QA receipt raw SHA-256:
`f045da50d2439458d276897c23f2e2c706bed309f6860d81bf95b3110a588dad`.
The filenames use synthesis-identity keys, which differ from these WAV content
hashes. Integration provenance is
`data/professional/provenance/retail-cart-basket-approved-audio-2026-10-16.json`.
Only the two audio descriptors and obsolete pending-audio note clauses changed.
All 1,897 prior audio files retained their exact hashes. Picture, morphology,
language, domain and curriculum statuses were preserved. Approval covers these
two exact clips, not future recordings or the in-game acoustic mix.

The subsequent R05 native delivery run passed 53 checks with zero failures for
all four integrated recordings, totaling 330,216 decoded bytes. Hash/decode,
round pinning, reuse, trimming and final zero-resource release checks passed.
R05's overall result remains failed because of a separate Node test-plan
registration omission. Full scoped results and the retained failure are in
`docs/qa/2026-10-16-approved-professional-audio.md`.

## Following batches

Pallet and shelf candidates were acquired in
`build/professional-english/retail-audio-review/pallet-shelf-acquired-r01/`
and presented for listening review. The user directly approved both samples;
their exact WAVs are now integrated. The separate approval addendum in
`sources/professional-retail-ava/pallet-shelf/listening-approval-2026-10-16.json`
records the original question identity and English translation of that reply.
Their original acquisition receipts remain pending historical records.
Technical QA passed 51 checks with
zero failures, no clipped samples, and exact full-stream equality to independent
MP3 decoding/resampling without effects. The prior 1,888 voice recordings, seven
collection notes and four integrated Professional recordings were checked
against their byte inventories and preserved.

| Approved recording | WAV SHA-256 |
| --- | --- |
| pallet | `8d4713a7e8576fa065ad1c9e1b18edcfc10b192254182fad626392a2de71893f` |
| shelf | `778fcf9304a06cd7ed04566cdc1f9bf28997bfbdbcd6e757f20ff9c3cb6282e3` |

The technical receipt raw SHA-256 is
`b8b48d66933d755ec46a1ecd41b3cc422bd8dc2a5c52c91a90afea016ff88c90`.
It uses R05 only as an unchanged registry/media byte inventory, explicitly
retains that run's overall failed result, and corroborates the registry against
the earlier pallet-image integration record. Technical QA does not confer
pronunciation or listening approval.

The subsequent user approval supplies that listening decision. Integration
copied the presented bytes without synthesis or processing and preserved all
1,899 prior voice, collection and Professional audio files. Permanent
provenance is
`data/professional/provenance/retail-pallet-shelf-approved-audio-2026-10-16.json`.
Only two audio descriptors and their obsolete pending-audio note clauses
changed. Exact image and morphology approvals, other lexical fields and all
draft curriculum gates remain intact. The seven scoped retail-media tests pass.
R08 native delivery passed 75 checks with zero failures for all six recordings,
using 495,324 decoded PCM bytes and returning to zero resources, bytes and
leases after release. The combined R08 result passed 185/185 Node tests and
914/0 morphology checks with unchanged measured inputs and registry.

Shopping bag and gift wrap candidates were subsequently presented for listening
review from `build/professional-english/retail-audio-review/bag-wrap-acquired-r01/`.
Their technical QA passed 51 checks with no failures, zero clipped samples and
exact full-stream equality to independent no-effects MP3 decoding/resampling.
The receipt raw SHA-256 is
`05535fbc6acb6b893afa57c14c3156897a3f12010512f598af5d4abe41d4ca29`.
The user directly approved both exact samples. The original question identity,
translated reply and presented hashes are retained in
[the bag/wrap approval](sources/professional-retail-ava/bag-wrap/listening-approval-2026-10-16.json).
Both WAVs are integrated without resynthesis or processing. All 1,901 prior
audio files were preserved: 1,888 historical voices, seven sequential collection
cues and six earlier Professional recordings. Only the two audio descriptors and
their obsolete pending-audio note clauses changed. Permanent provenance is
`data/professional/provenance/retail-bag-wrap-approved-audio-2026-10-16.json`.

| Approved recording | WAV SHA-256 |
| --- | --- |
| shopping bag | `6c7d2ac0e733214faf920a4a0781d0458b6b891a92aa07b7ab433b501d19de72` |
| gift wrap | `cad8619dad6e225ce73c835ce5e90f7252c42af3c546aaa393adcd8db3e0f3a2` |

Focused native delivery passed **97 checks with zero failures** across all eight
recordings. Complete decode, exact hashes, dependency admission, round leases,
reuse, trimming and release passed; 660,432 decoded PCM bytes returned to zero
resources, resident bytes and leases after release. Registry and measured inputs
were unchanged. Receipt: `build/professional-english/retail-audio-review/bag-wrap-acquired-r01/native-delivery-r01.json`,
raw SHA-256 `6b658c3efb4a79ead54687a99767fa4903de37001da4f4ba1d99996b468b11fc`.
This focused result does not extend the historical six-recording R08 receipt.
All curriculum modules remain draft, and the in-game acoustic mix is unreviewed.

`tools/generate-professional-voices.cjs` prepares a course/module-scoped manifest
from language-reviewed sense records. It verifies and retains existing integrated
audio, reuses complete hash-verified candidates, and acquires only missing
candidates when explicitly passed `--acquire`. It never changes lesson metadata,
copies candidates to production, or promotes pronunciation approval.

The original prepared-only manifest for these two picture-complete terms was
created with:

```powershell
node tools/generate-professional-voices.cjs --course retail --module module03 --sense shopping-cart.store-trolley.n --sense shopping-basket.store-container.n --output build/professional-english/retail-audio-review/cart-basket
```

Add `--acquire --python build/professional-english/retail-audio-review/client-7.3.1/Scripts/python.exe`
to use the already acquired pinned client. The tool submits the exact term text;
it does not borrow Growth's sense-specific homograph contexts. Context-dependent
pronunciations must be checked for the selected sense. New outputs remain
candidates until their own pronunciation review, even though the Ava Sweet
profile is approved. The remaining 38 language-reviewed terms
in Retail module 03 are the next bounded batch. Expressions remain separate.

## Counter and checkout approval

Two further candidates were acquired after successful R11 validation and
presented for user listening. The user directly approved both exact recordings. They are now integrated
through a committed guarded transaction. Both use the exact saved Ava
Sweet profile and the pinned edge-tts 7.3.1 client.

| Term | Exact candidate WAV SHA-256 |
|---|---|
| counter | `685b544dbb353f3a1f3fb999fbe3f541cb94874d0e4543ad0cba774c39fd4bc3` |
| checkout | `39df6ba3406a891283f99379ca8526d93fc8f3279b571134c0213dd824282224` |

Technical inspection passed 51 checks with no failures. Both complete PCM
payloads exactly match independent untrimmed source-MP3 decoding, with no
effects and no clipped samples. All 1,888 historical voices, seven collection
cues and eight integrated Professional recordings remain byte-identical.
This establishes file and conversion integrity, not listening quality.

The immutable acquisition receipts, retained MP3s, WAVs, technical inspection
and listening request are under
`build/professional-english/retail-audio-review/counter-checkout-acquired-r01/`.
Technical receipt SHA-256:
`5300530a5630b15ca27921f488f123ef228fab38d89cc9ad982e3f71460b608b`.

The direct approval is retained in `human-approval-r01.json` beside these candidates
(raw SHA-256 `d9487d9a2a2a93805fa597f87dcf775f1cebae88c89fc97c13de90acbece2e82`).
It binds the exact presented WAVs and original pending listening request without
rewriting acquisition history or resynthesizing audio.

The exact approved bytes were copied without resynthesis or processing. The
integration preserved all 1,903 earlier recordings and the collection source
master. Only two audio descriptors and their exact obsolete pending-audio note
clauses changed. Counter retains its accepted image and pending domain gate;
checkout retains its not_required domain gate. All other review, morphology,
media and curriculum fields remain exact. The direct approval is also retained
in [the production listening record](sources/professional-retail-ava/counter-checkout/listening-approval-2026-10-16.json).

Integration receipt: `build/professional-english/retail-audio-review/counter-checkout-acquired-r01/delivery-r01/integration-receipt.json`,
raw SHA256 `423fc687ccd469fa12c71f25deea84fd90b40c35d0eebadc7d4ea7112cc8aa8f`.
The transaction journal records committed state. Subsequent R14 verification
passed **192/192 Node tests, 1,210/0 native morphology checks and 119/0 native
approved-audio checks**, with no skips and unchanged measured inputs/registry.
All ten recordings decode to exactly 825,540 PCM bytes in the bounded cache;
resources, resident bytes and leases return to zero after release. This proves
scoped delivery, not the in-game acoustic mix or module readiness.

Failed R13 remains preserved: the new test incorrectly expected both domain
flags to be pending. The corrected test requires the original per-sense values
and complete review-object equality; production data needed no correction.
R14 receipt raw SHA256: `826a90b1aa354f16d484f7bd88c85b200fdec6ee0146d4ffa875bcc9c634877d`.

## Card reader and barcode approval

Card reader and barcode were acquired with the same exact profile and pinned
client. Their 51 technical checks passed: full PCM matches independent decoding
without effects or trimming, and neither clip contains clipped samples. The
exact candidates and listening request are retained under
`build/professional-english/retail-audio-review/card-reader-barcode-acquired-r01/`.
Technical receipt raw SHA256: `ef75d3504e385ef1c4037a30609d35658cfeca5636af363d76edccd27d4c49f1`.
The direct human reply in `tesis-iter-4` approved both exact presented samples.
The recovered question and turn identifiers, translated reply and exact hashes
are retained in [the listening approval](sources/professional-retail-ava/card-reader-barcode/listening-approval-2026-10-16.json).
The original acquisition and pending-listening records remain unchanged.

| Approved recording | WAV SHA-256 |
| --- | --- |
| card reader | `acd48c920c631906e6ff0775cf3f373c247687fcb128b41e3ce0f3bdf668ba45` |
| barcode | `01b2666324e5e373b75799535d8a78494a6afe8225c4b82147975d55405c96e5` |

A guarded transaction copied these exact WAV bytes to their content-addressed
production paths without resynthesis or processing. Only the two audio
descriptors and their obsolete pending-audio note clauses changed. All 1,905
prior audio files, the collection source master and all eight integrated images
retained their hashes. Barcode retains its accepted image; card reader's image
remains pending. Language, domain, morphology and curriculum gates are unchanged.
Permanent provenance is
`data/professional/provenance/retail-card-reader-barcode-approved-audio-2026-10-16.json`.

The focused audio/media Node tests passed **22/22**, with zero failures or skips.
Native delivery passed **141 checks with zero failures** for all twelve recordings,
including exact hashes, complete PCM decoding, dependency admission, round leases,
reuse, trimming and final release. The twelve clips use 990,648 decoded PCM bytes;
resident resources, bytes and leases return to zero. Measured inputs and the
registry remained unchanged during native verification. Receipt:
`build/professional-english/retail-audio-review/card-reader-barcode-acquired-r01/native-delivery-r01.json`,
raw SHA256 `809dca51fe175c706fe8403d465c98b7812b22123dc614a334c354c35b8a13b1`.
This subsequent result completes the integration record's pending native-delivery
step without rewriting that record. It does not establish physical-device
playback, in-game acoustic balance or module readiness; all 200 modules remain draft.
