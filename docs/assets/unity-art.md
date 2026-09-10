# Unity Store art import

The game remains a Godot game. Unity is used offline to import selected licensed
art; no Unity runtime or third-party scripts are added to the game.

## Source and current status

Candidate: [Food Icons Pack by Angelina Avgustova](https://assetstore.unity.com/packages/2d/gui/icons/food-icons-pack-70018),
free under the [Standard Unity Asset Store EULA](https://unity.com/legal/as-terms).
The store describes 100 transparent 256px food PNGs (41.3 MB, version 1.0,
September 13, 2016). Actual downloaded artwork must be checked before deciding
which nouns it can illustrate.

Also researched: [Free2DMegaPack by Brackeys](https://assetstore.unity.com/packages/2d/free-2d-mega-pack-177430),
free under the Standard Unity Asset Store EULA. Its listing describes 230+ sprites
and 15 sounds (10.5 MB, version 1.0, September 8, 2020), usable in commercial and
noncommercial projects. It is a candidate for decorative game props; a listing
alone does not establish that a sprite clearly illustrates any vocabulary word.

**Acquisition is pending as of September 11, 2026.** No package from either listing
has been downloaded, no real Unity artwork import has completed, and no licensed
PNG override has been shipped. The installed Unity CLI and Editor are available
for import, but the CLI has no Asset Store download command. Acquisition still
requires Unity's authorized Asset Store or Package Manager workflow.

On September 11, Windows Computer Use reached the Food Icons Pack listing in
stable Chrome and selected Add to My Assets. Unity redirected to its sign-in page;
that Chrome session is not signed in. Authentication was left for the user. The
separate in-app browser connector returned `Codex auth token is unavailable`.
Neither result was an automatic safety rejection. Acquisition and CLI import
remain unverified until the authorized signed-in session or package is available.

The mapping intentionally starts with no selected images, version, or package
hash. A store listing is not proof of a download or import. Fill those fields from
the downloaded package and its inventory before running an import.

The source package, isolated Unity project, generated import evidence and PNG
overrides are ignored by Git. They are not distributed as a public asset library.
After acquisition, selected textures are to ship inside the compiled game; the
repository retains its original SVG fallback for every word. Obtain the asset through the publisher's
authorized Unity Store workflow and use it subject to its license.

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

Edit `docs/assets/unity-food-icons.mapping.json`. Copy the package SHA256, record
the acquired version, and add only images whose actual picture clearly matches
the given vocabulary word. One source image may represent only one noun.

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
  -batchmode -nographics -quit -importPackage <selected-art.unitypackage>
  -logFile <unity-import.log>
```

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
