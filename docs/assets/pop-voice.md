# Voice Pop report recordings

The report uses prerecorded Microsoft Azure Speech **en-US-JennyNeural** audio,
matching the existing vocabulary voice: `friendly` style, degree `1.15`, and an
8% slower speaking rate. Numbers are spoken inside complete recorded sentences;
the game does not assemble number fragments or use the browser's default TTS.

`pop-voice-prompts.json` is a flat object mapping 51 stable IDs to their complete
English scripts. The batch contains **2,158 source text characters**. WAV paths
are `assets/audio/pop/<id>.wav`; the original 200 vocabulary recordings and 22
existing prompts remain separate and unchanged by this generator.

## Report content

- `round-0` through `round-20` report the actual number of pops in 30 seconds,
  with a singular sentence for one pop and an encouraging sentence for zero.
- `combo-1` through `combo-20` report the actual best combo.
- `highlights-one`, `highlights-two`, and `no-highlights` introduce the round's
  actual successful words or the zero-hit coaching message.
- `practice`, `practice-next`, `repeat`, and `repeat-next` introduce an actual
  word from the round, then explain how to hear or practise it.
- `ready`, `high-five`, and `round-fallback` cover the remaining short responses.

Runtime selection must use the real result. A count outside the recorded range
uses `round-fallback`, while the exact results remain visible; an unsupported
combo must not be clamped to a recorded value. Successful and practice word
clips come from the existing vocabulary recordings, selected from this round's
actual result. Pop count and unique-word count are different measurements.

## Provider, authorization, and cost boundary

The existing personal Azure resource is `tesisgame-speech`, resource group
`rg-footises`, region `eastasia`. A read-only Azure account query on 2026-09-18
confirmed `kind=SpeechServices` and **`sku=F0`**. The generation command checked
F0 again immediately before retrieving the existing credential. No resource was
created and no paid tier was enabled.

This follows the established project workflow documented under "Regenerate
natural speech" in `README.md`; the 2026-09-11 catalog audit also records prior
use of this same F0 resource. The current task explicitly authorized this small
report batch. The generator waits 3,200 ms before each synthesis request to stay
under the existing F0 transaction limit. The 2,158-character figure measures
source text, not an invoice or a statement of remaining monthly quota.

Credentials exist only in the generation subprocess environment and are cleared
in `finally`. Request headers, provider error bodies, and keys are never printed
or written to source or Web exports. Playback uses local assets and makes no
runtime requests to Azure Speech.

## Generation and validation

Use the credential setup and cleanup documented in `README.md`, then run:

```powershell
node tools/generate-pop-voices.cjs --missing
```

`--missing` generates only absent report recordings. Omitting it regenerates the
51 report recordings, without touching the original vocabulary or prompt folder.
FFmpeg must be on PATH; this batch uses FFmpeg 7.0.2.

The generator reuses `speechMarkup` and `convertVoice` from the existing voice
generator, validates the provider's neural voice and friendly-style availability,
rejects redirects, and bounds each HTTP request to 30 seconds. Azure produces
24 kHz PCM16 mono; FFmpeg preserves quiet endings and internal pauses while
trimming excess final silence, then produces **22,050 Hz PCM16 mono** WAVs.
Both the source and converted WAVs must pass structural and audible-sample
validation. All synthesis and conversion finishes in a private staging directory
before any final recording is published. A synthesis or conversion failure
leaves existing recordings intact.

The Web build must keep these optional recordings outside the startup PCK,
publish the Godot-imported audio as optional assets, and load them through the
game's audio path. The generator does not run Godot or change import settings.

## Asset inventory

Generated and verified on 2026-09-18: **51/51 WAVs passed**,
totalling **9,507,592 bytes** and **215.541 seconds**.
Every file is 22,050 Hz PCM16 mono and contains at least 20 ms above the
validation noise floor. The original `assets/audio/voice` directory has no
Git changes. No Godot process was run by the asset generator.

Manifest SHA-256 (UTF-8, LF line endings):
`b7b54e84a3efe91c09e29df4ee1d11641b80f65c97c85d3eb7b663514599d6a7`.

Offline generator checks also passed: invalid credentials or region trigger
no request; HTTP failures discard provider response bodies and expose no
credential; a missing friendly neural voice fails without fallback.
After generation, `--missing` was checked with a request function that rejects
all network use: it made zero requests, regenerated zero clips, and preserved
all 51 WAV hashes.

Format and non-silence checks establish acoustic integrity; they are not a
claim of human listening or a pronunciation assessment.

| ID | Seconds | Bytes | WAV SHA-256 |
| --- | ---: | ---: | --- |
| `round-0` | 7.361 | 324684 | `a9c57b97acf928f5a655f0e0328ed8aec32ee2fdcbe14efc86dcc75b850cd1f8` |
| `round-1` | 4.365 | 192550 | `52d589814f1fa237b5699bc391c9c92d4bc59d9a53e3ab379f39d40b517d2db0` |
| `round-2` | 4.379 | 193150 | `f9f9745cd2a6557b340fa438095bbbf1e8c890367406e4ade89541cd33f0d0c9` |
| `round-3` | 4.449 | 196246 | `3072f25cd846f739f66d7a505a6dd86d05b16ae193c9bae10fc8437fd6848d85` |
| `round-4` | 4.447 | 196146 | `9323827566549cf8837e20a5ae40fc0810922cc595629fd16fdfc4204d4c176e` |
| `round-5` | 4.433 | 195548 | `8dfb407a650fbcc9df1851e9b4c1bdbfeddb5641649bb886f4e04a64b19b709b` |
| `round-6` | 4.460 | 196746 | `ddb9f66b27c0e89047f3f8ce025f1ec842bc586924e6649a9174da290aa3693e` |
| `round-7` | 4.515 | 199142 | `e847e81d2c3400674a6ff4ed48c552fa8f03a1c604a971cc9876efe47da6a6f8` |
| `round-8` | 4.297 | 189556 | `3bcaee20d4104504040e8dd0df68d33df9e000cce88fb949408fd08134d4ff00` |
| `round-9` | 4.447 | 196146 | `fa075fd06544925b236b01a444fd547981df84d068b4b70f75742e76d4c595df` |
| `round-10` | 4.433 | 195548 | `8cc70f2e9dec42b6d7e79c3e0be507088944af1514db646b2dc1ea161d902252` |
| `round-11` | 4.555 | 200940 | `47745abb39950c7801bf6c32ec4e0e09d05baa4b4ce20b191ab66964942e6a0e` |
| `round-12` | 4.501 | 198542 | `9a7297ecba9c1826ef83ef68b7b82029568be94631d173f61d5aaec4e551c3bb` |
| `round-13` | 4.734 | 208830 | `69e7837a909e3d513e2c1648bae90aa006a1840419e767eaf0466891da3d52f0` |
| `round-14` | 4.664 | 205732 | `e56a9ef081901e9f4bdc2cd30ceadef1477021d9a89f3ef42a58549920015b5b` |
| `round-15` | 4.637 | 204534 | `154601c82586c4a918747bb9ea8960865d18b01c9ae1257501baac1b7510caf5` |
| `round-16` | 4.678 | 206332 | `3a2b04e8ce575ee3a2fb14551b70d35965f23415db2d7efc718a4bda416708c1` |
| `round-17` | 4.773 | 210526 | `1178123c869c878400db3226fece2d8e00085b36dc174187db755a5daa1a0b8d` |
| `round-18` | 4.610 | 203336 | `439f93043471df1ecc92646b5112ffa8e212397dcbef95fd9bfb9812792879f2` |
| `round-19` | 4.626 | 204036 | `bbb0598976c21514c71249af2c1a45789bca01f284d6e8fe73d22d6f5a33b355` |
| `round-20` | 4.542 | 200340 | `76855c900d1b50c0eb125ef9493bec36e918cb17af54563024cb0b4de6d84767` |
| `combo-1` | 3.632 | 160226 | `006c926cc78f135eb9b1dac058f18bcd9afb17b0eef8c269856c0be5d4ab840f` |
| `combo-2` | 3.700 | 163220 | `47cc0bd7bea9ec8126420435ab290c342fc414001b45acc9fa5f7a81c0edda6b` |
| `combo-3` | 3.741 | 165018 | `49c9572b233e3d1d99b4c5b4583f9c4ed25beeefee42a0c20c7ae2480bbee66a` |
| `combo-4` | 3.673 | 162022 | `2cad0d644f5b66b716990811c7334984cc928f9656a0290b62e62f91c1190b2d` |
| `combo-5` | 3.850 | 169812 | `d348d702e30380fefa541594b225983ab4434b3c7991b5308212923546e937b0` |
| `combo-6` | 3.850 | 169812 | `70a27da00e0cdeeb4789f892cb565260024d466ad9423f1f5ff431ab06f7c265` |
| `combo-7` | 3.743 | 165118 | `88f79a664ae18b13ab3f26239a1f77f1df83320daf2ee4026b19dd23d8edd906` |
| `combo-8` | 3.716 | 163920 | `2b2d7e4934b082569a46a952c7bbea3af826bf4580b99d8624e0905f40ed6a68` |
| `combo-9` | 3.702 | 163322 | `0005cc6e66255230693f28d9be2c8605454b6d15a743234a46c1fb4f3f022d69` |
| `combo-10` | 3.727 | 164420 | `04c8c033d99b2fe5a91c2b57e114b31b0d5b06aef0785b546f617d3ef317d8bd` |
| `combo-11` | 3.877 | 171010 | `24c10950a153cc14aca1bf6646dfeec3c42dc91b6c0bb7de7011fd85cc704187` |
| `combo-12` | 3.850 | 169812 | `36dd5f5cd1deb79e8c098d209fec30714ff42719c7ebea3d24d4b5b56435a376` |
| `combo-13` | 4.053 | 178800 | `6b64806669821931fa346cd690a23519b64f5da74936479518160851aa16a3bd` |
| `combo-14` | 3.985 | 175804 | `85bc87d7c0547e8ccd8548191ad02d2a29abf074a6aacdeb7fc7ad2da96cf520` |
| `combo-15` | 3.945 | 174006 | `e86f3f4a93fcb225fe4d73f888cb2b3bd8c00c7770d647f89c5ad0a6029d4e11` |
| `combo-16` | 3.988 | 175904 | `dda615e73145c4bab8ca6515416311f184ff66d53d7d8180f04c3326ad08eca3` |
| `combo-17` | 4.040 | 178200 | `72cd056130e4f3b2a42279c98e29d236cee9e2bf05f6d06ff39e85f8ba8cb6fd` |
| `combo-18` | 3.931 | 173408 | `493d74efd12b61d57b3dfc97f88ce38e9fc973d990145fc1fdde237d75761780` |
| `combo-19` | 3.972 | 175204 | `22f224baaa773c0994398fb4c5483927093abf34d17b37ac849e90038aecbe25` |
| `combo-20` | 3.890 | 171608 | `7cc185ec63d7e614d4a194919801bd7a601e73e920a0668f5de0e4f812ead65d` |
| `highlights-one` | 3.928 | 173252 | `352f3966166a3c37e317682b2580aa37125ccc458da40c5ec35213a9defe6a6a` |
| `highlights-two` | 4.205 | 185504 | `0bd2c07b274f6cec73c76316ec78a72de5e0c5fc2cb2ecf09d858950faa00a86` |
| `no-highlights` | 6.118 | 269828 | `dd4e63a6248adc1e86f279342035b13b92aa7d6e9f00adfbd2d6ba2941ddfff7` |
| `practice` | 2.372 | 104648 | `95ea7ae95477ac557991f66419c7801cc685d29fc0891dbb5a6df56d89c2190b` |
| `practice-next` | 4.232 | 186684 | `4b884e8ae5901a7d9ead87514bf8f96088353e2d9c099b738048a8cee78a116b` |
| `repeat` | 2.031 | 89592 | `4047797aec486f13bdb84280e36e530197a26c6795e02d48252e50a845b06678` |
| `repeat-next` | 6.063 | 267406 | `a74710430e5eeb4f62f89cfadd694ca50319d2bf97018c88de40813cfb96f662` |
| `ready` | 6.122 | 270034 | `a9c315435ee9a1502dbd48cc80b5c969f4e871064f92a22953fc12923a26593b` |
| `high-five` | 1.289 | 56888 | `9ed37521df9212575381fb8fd6a61d19b5123c9390d91af972acc5f40a6a3868` |
| `round-fallback` | 4.409 | 194500 | `b1d09ab7c7a92c2592d35a99fcf1f04102d558a2ae225d89a9bd29d8a1de6ea3` |
