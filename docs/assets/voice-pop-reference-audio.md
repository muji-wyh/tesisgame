# Voice Pop reference blade and cut audio

The user supplied `fruit_ninja.mp4`, a 56.8-second gameplay recording. Its
single mono AAC track contains game effects mixed together. These assets are
short filtered excerpts, not isolated original sound stems. Filtering reduces
low rumble and short fades remove abrupt boundaries; it cannot remove every
background element or restore information lost in the recording.

The first blade gesture at approximately 1.22 seconds and fruit impacts at
1.37, 1.47 and 2.39 seconds provide three short variants. Each finished hit
contains the blade and cut in one mono WAV. The cut layer starts 32 milliseconds
after the blade; the recorded cut attack follows within the next few
milliseconds. One playback request therefore keeps both parts synchronized,
including on a busy browser frame. The visual rupture uses this same brief
lead-in. Runtime pitch remains 1.0 and consecutive hits choose different
variants independently of gameplay randomness.

The finished hits last 277, 297 and 317 milliseconds. They use 44.1 kHz PCM16,
no loops, and a sample peak ceiling of 0.62 (-4.15 dBFS). At the 0.24 runtime
gain, even three exactly coincident peak samples sum to at most 0.447. The
happy Pip call is not layered over successful Voice Pop hits. Pip still jumps
to celebrate, and missed targets retain the sad Pip recording. Actual device
volume and microphone leakage still require listening on physical hardware.

Three fixed hit channels allow a short burst of words to finish their sounds.
A fourth simultaneous hit replaces the oldest channel. Ordinary button effects
and Pip's sad miss reaction use their own players. Muting, hiding the page,
leaving the mode and stopping the game all stop every hit channel and invalidate its
playback request; resuming cannot replay old hits.

All three local resources load at game audio startup and ship inside the game
pack. A first hit or an offline hit never requests an audio file from the
network. The runtime prefers this bank only when all three clips are playable.
Without the private bank, the eight previous fruit slices remain available,
followed by the earlier single slice and the tracked selection sound. A Web
export with a present but incomplete reference bank is rejected.

The source video, excerpts and Godot import metadata follow the repository's
existing private-audio convention and remain outside Git. The checked-in
manifest records the source hash, exact windows, processing, final hashes and
levels; no additional ownership or redistribution rights are implied.

To reproduce with FFmpeg available on `PATH`:

```powershell
node tools/import-pop-reference.cjs 'C:/uworks/fruit_ninja.mp4'
npm run import
npm run build:web
```

The importer verifies the reviewed video's SHA-256 before modifying anything.
It decodes directly to floating point before filtering, avoiding an additional
integer clipping stage, and prepares all three variants before writing them.
Godot imports preserve the final PCM without normalization, trimming, looping,
or compression. Exact decoded sample hashes can depend on the FFmpeg build;
the generated manifest must accompany the reviewed local assets.
