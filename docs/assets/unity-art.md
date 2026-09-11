# Unity Store art import

The game remains a Godot game. Unity is used offline to import selected licensed
art; no Unity runtime or third-party scripts are added to the game.

## Source and current status

Acquired: [Food Icons Pack by Angelina Avgustova](https://assetstore.unity.com/packages/2d/gui/icons/food-icons-pack-70018),
free under the [Standard Unity Asset Store EULA](https://unity.com/legal/as-terms).
Version 1.0 was downloaded on September 11, 2026 through the official Unity
Editor Package Manager **My Assets** workflow. The downloaded package is
43,257,555 bytes; archive inspection confirmed 100 PNGs, each 256 × 256 pixels.
Its SHA256 is
`ba54f508dc982fec10d64adbdd980dcc2f5b767cda77cb50440215e110d76bc5`.
The inspected package version, source paths and selected image hashes are recorded
in [the mapping](unity-food-icons.mapping.json).

Also researched: [Free2DMegaPack by Brackeys](https://assetstore.unity.com/packages/2d/free-2d-mega-pack-177430),
free under the Standard Unity Asset Store EULA. Its listing describes 230+ sprites
and 15 sounds (10.5 MB, version 1.0, September 8, 2020), usable in commercial and
noncommercial projects. It is a candidate for decorative game props; a listing
alone does not establish that a sprite clearly illustrates any vocabulary word.

**Acquisition, source-art review and verified CLI import are complete; final
deployed use remains pending verification.** Free2DMegaPack was not downloaded or
integrated in this task.
The installed Unity CLI handles offline import, not Asset Store download.

An earlier Computer Use attempt opened the listing in external **Chrome Canary**
and reached Unity sign-in. That did not establish the login state of the user's
separately signed-in embedded browser. The embedded browser connector returned
`Codex auth token is unavailable`, an app authentication failure rather than an
automatic safety rejection or evidence of a signed-out Unity account. Native
sidebar interaction subsequently claimed Food Icons Pack under the user's
explicit authorization, and Editor Package Manager downloaded the package.

The source package, isolated Unity project, generated import evidence and PNG
overrides are ignored by Git. They are not distributed as a public asset library.
Selected licensed textures ship inside the compiled game after verified import;
the repository retains its original SVG fallback for every word. Obtain the
asset through the publisher's authorized Unity Store workflow and use it subject
to its license. A clean checkout without the ignored overrides uses the original
art; publishing imported art requires the verified local files at build time.

## Teaching selection

All 100 actual PNGs were visually inspected in four contact sheets. The selected
19 pictures were also compared with the original SVGs at 64px card size:
apple, banana, orange, pear, grape, cherry, melon, carrot, tomato, corn, peas, egg,
bread, cake, cookie, cheese, acorn, fish and squid. No new vocabulary was added.

The choices use recognizable fruit and vegetable silhouettes, visible orange and
melon interiors, intact egg shells, a bread loaf (`bread2.png`), a complete cake
(`cake3.png`), cookies, cheese and an acorn. `fish2.png` shows an intact fish;
`squid.png` has a long mantle and distinct tentacles. The source filenames and
hashes in the mapping preserve the publisher's exact names, including
`apple .png`, `bananas.png`, `grapes.png`, `melone.png`, `eggs.png` and `cookies.png`.

The original milk and water images remain because they show their contents more
clearly than the pack's jug and bottle. The original root diagram, single
raspberry and empty spiral shell remain: the pack's special root shape, berry
cluster and bivalve shell would weaken the current teaching cues or the
shell/clam distinction. Review evidence is under `build/unity-food-review/`:
`inventory.json`, `contact-1.png` through `contact-4.png`, and
`independent-64px-comparison.png` (source SVGs beside crops of the rendered PNG
sheets). The final local game also passed 38 Learn/Hear observations across
phone and desktop sizes, with Match and quiz feedback visually reviewed.

## Inspect, map and import

Requirements: Python 3 (standard library only), installed Unity CLI and a licensed
Unity Editor. Defaults use the current Windows installation; override `-Python`,
`-UnityCli` and `-EditorPath` if necessary.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/import-unity-art.ps1 `
  -Package build/downloads/FoodIconsPack.unitypackage -InspectOnly
```

Inspection reads the archive without extracting its paths. It rejects traversal,
links, duplicate entries and oversized assets. Its JSON output includes each
PNG's exact source path, dimensions and SHA256 and the complete package SHA256.

The checked-in `docs/assets/unity-food-icons.mapping.json` records the acquired
version, package SHA256 and 19 reviewed source images. For a future package or
mapping revision, record its inspection hashes and select only actual pictures
that clearly match their vocabulary words. One source image may represent only
one noun.

```json
{
  "word": "apple",
  "source": "Assets/PublisherFolder/ActualAppleFilename.png",
  "sha256": "the exact SHA256 from inspection"
}
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/import-unity-art.ps1 `
  -Package build/downloads/FoodIconsPack.unitypackage `
  -Mapping docs/assets/unity-food-icons.mapping.json
```

The tool verifies selected IDs against `words.json`, checks every source hash,
and makes an art-only package with fresh built-in texture metadata. It retains no
third-party code, prefabs, shader source, project settings or custom importers.
It creates a fresh project under `build/unity-asset-staging/<run-id>` and executes
the installed CLI with these Editor flags:

```text
unity run <staging> --editor-path <editor> --timeout 300 --
  -nographics -importPackage <selected-art.unitypackage>
  -logFile <unity-import.log>
```

The CLI manages batch mode and process exit. Do not pass `-batchmode` or `-quit`
after `--`: the installed CLI rejects both as reserved flags. Those rejections
were verified before correcting the wrapper; they are not successful imports.
The wrapper writes the minimal `Packages/manifest.json` and
`ProjectSettings/ProjectVersion.txt` as ASCII. Windows PowerShell's UTF8 encoding
adds a BOM, which caused the earlier staging-project parse failure.
Do not add `-noUpm`: Unity does not support it together with `-importPackage`.
After successful exit, every imported PNG must match its selected source hash
and have Unity texture metadata. Only then are the PNGs copied to
`assets/imported-unity/<word>.png`; the game's data loader uses that override
when present and otherwise loads the original `words.json` SVG.

Each verified mapping is the **complete managed override set**. A later smaller
mapping removes obsolete PNGs recorded by the previous manifest, along with their
recognized Godot texture remaps, after validating every new imported image. This
prevents a removed image from remaining active through Godot's import cache.
The tool refuses an override directory redirected elsewhere, unrecognized PNGs,
modified managed images, and unrecognized remaps; it does not delete those files.
Keep unrelated artwork outside this reserved directory. Retain the manifest so
the next import can verify file ownership and provenance before replacing art.

## Import and release evidence

Each run writes `build/unity-art-import/<run-id>/prepared.json`,
`unity-command.json` (the exact command and exit code) and `unity-import.log`.
`assets/imported-unity/manifest.json` lists verified imported PNGs and hashes.
Keep the source mapping in Git; keep licensed images and source package ignored.
Run `node --test tests/unity-art.test.cjs` for archive/mapping safety checks, then
the normal Godot import and web build. Inspect the actual art in Learn and quiz
views. Verify the exported and deployed game contains and displays selected
overrides before calling the Unity integration complete.

The real September 11 import succeeded in
`build/unity-art-import/20260911-122407-933036cc/`. Its `unity-command.json` records
CLI exit code **0**, and `unity-import.log` ends with successful batch-mode exit.
The art-only package SHA256 is
`890302ad3f046404564106a8ca7b2125304411c098eded299e8b9b7a25478758`.
`assets/imported-unity/manifest.json` records **19 verified imported images** and
the matching isolated staging project. An independent check of the 19 copied
PNGs reproduced every selected source hash. Generated TextureImporter metadata
uses the installed Editor's serialized version 13; the final import has no
version warnings. A separate Editor check loaded all 19 assets as transparent,
single 256px Sprites, with zero failures (`sprite-validation.json`). The final
Godot pack selected all 19 PNG overrides and retained all 140 SVG fallbacks.
See [release QA](../qa/2026-09-11-unity-food-art.md) for tests and deployment status.

## Original semantic artwork

`node tools/generate-images.cjs` reproduces the original SVG fallback artwork.
The learning pass changed twelve nouns:

| Words | Visual cues |
| --- | --- |
| spoon | Narrow metal handle and shaded concave bowl |
| towel | Folded bath towel on a bathroom rail, without scarf fringe |
| coat | Long sleeves, long hem, hood and toggle fastenings |
| milk | Milk carton with cow spots and a glass of opaque white milk |
| arm / leg | Open hand and elbow versus straight calf, bare heel and toes |
| head | Complete head, hair and ears with a faint neck/shoulder context |
| berry | One raspberry with visible clustered fruit segments |
| shell / clam | Empty spiral shell versus open bivalve containing the animal |
| comet / meteor | Icy nucleus and two blue tails versus a fiery atmospheric streak |

The two astronomical drawings and the shell/clam pair are still teaching
illustrations, not mutually exclusive definitions. The quiz excludes overlapping
word pairs. A contact sheet was rendered for comparison in
`build/visuals/semantic-art-before.png` and `semantic-art-after.png`.

The September 11 [full original-catalog audit](../qa/2026-09-11-catalog-semantic-audit.md)
reviewed all 140 illustrations and independently transcribed the actual word WAVs.
It additionally clarified doll (visible rag-doll construction) and brush
(projecting bristles), and records the acoustic evidence and limits for the new
"A kite." recording. The separate import evidence above establishes the real
Unity CLI import; the original-only audit does not establish final deployed
imported-art appearance or pronunciation.
