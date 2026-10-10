# Gold coin artwork

The wallet and chest payout use a warm gold adaptation of the already acquired
Toon FX coin artwork. Its beveled rim, visible thickness and authored metal
highlights remain intact. The front face is legible at a small HUD size; three
additional source views give flying coins consistent material and perspective.
No geometric substitute, listing screenshot or extracted reference-video image
is used.

## Source, rights and status

| Field | Evidence |
| --- | --- |
| Source | [Toon FX, product 25601](https://assetstore.unity.com/packages/vfx/particles/toon-fx-25601), version 1.52 |
| Creator | Kenneth Foldal Moe (Archanor VFX), credited in the acquired package README |
| License | [Standard Unity Asset Store EULA](https://unity.com/legal/as-terms); the existing acquisition and official listing check are recorded in [the chest fragment effects record](jelly-fragments.md) |
| Acquisition | Previously acquired local package at `C:/uworks/AssetsSource/Toon FX [1.52]`; no new purchase or preview-image acquisition |
| Actual source | `Textures/coins.png`, 1024 x 1024 RGBA, texture GUID `1699dbd54fcee0a46856002fbff1b84a` |
| Source SHA-256 | `ee6f261c5c0ef92aeef1f1885375336d472f166bd6835ee18957626f46a98077` |
| Conversion status | Source inspected; two optimized PNG build inputs prepared and inspected over pale and dark backgrounds |
| Runtime status | Integrated into the header wallet and arrival-driven chest payout; native captures reviewed at desktop, phone portrait and short landscape sizes |

The package README explicitly describes monochrome textures intended for vertex
color and gradient recoloring. `Materials/Coins01.mat` references the inspected
source atlas. `Prefabs/Coins/CoinBlastGold.prefab` supplies an existing gold color
direction and a 2 x 2 particle UV layout. The adaptation adds warm amber shadows
and pale cream highlights through a documented luminance lookup, preserving the
original shading and alpha. It is not a claim to reproduce Unity's shader exactly.

Licensed texture bytes and Godot import sidecars stay ignored private build
inputs, consistent with the existing Toon FX and chest artwork. They ship inside
the compiled game rather than as a reusable public sprite library. The source
package, Unity material, prefab and scripts are not copied into the game. The
checked-in preparation script and manifest allow a licensed local copy to be
restored with source hash verification.

## Runtime inputs

| Path | Size | Use |
| --- | --- | --- |
| `res://assets/coins/gold-coin.png` | 128 x 128 RGBA, 16,547 bytes | Static front-facing HUD icon and main payout coin |
| `res://assets/coins/gold-coins.png` | 256 x 256 RGBA, 42,494 bytes | 2 x 2 atlas of additional payout perspectives |

Atlas cells are 128 x 128 pixels, in row-major order:

| Cell | Region | Authored view |
| --- | --- | --- |
| 0 | `(0, 0, 128, 128)` | Front |
| 1 | `(128, 0, 128, 128)` | Narrow edge |
| 2 | `(0, 128, 128, 128)` | Almost horizontal |
| 3 | `(128, 128, 128, 128)` | Tilted three-quarter |

These are four independently authored views, **not a sequential spin flipbook**.
The source contains copper, silver and gold Unity particle bursts, but no separate
coin skeleton or continuous coin spin clip. In-game flight, rotation, arrival and
reward timing belong to the game. A frame should retain its original proportions;
randomly switching these four views as an animation would introduce visible jumps.
The HUD uses the front face without idle motion. Reduced motion can retain that
same front face without flight or spin.

The common source-cell crop is `(48, 48, 464, 464)` within each 512px cell, followed
by Lanczos downsampling to 128px. All four source silhouettes fit that crop. The
original transparent contours and relative angle widths are preserved. No baked
drop shadow or glow limits the icon to a particular background. Output hashes,
exact color stops and frame metadata are in `assets/coins/manifest.json`.

## Rebuild and visual review

Run from the repository root with Python and Pillow:

```powershell
python assets/coins/prepare.py
node tools/prepare-coin-art.cjs
```

Use `--source` to provide another path to the same acquired texture and `--output`
to choose a preparation directory. The source SHA-256 must match the inspected
version. The script writes both runtime inputs, the manifest, and an ignored
`assets/coins/review-contact.png`. It does not start Godot or Unity.

The Node preparation command verifies both PNGs against the manifest before
writing lossless Godot texture settings. It preserves alpha, dimensions and
color channels without mipmaps or runtime resizing. `node
tools/prepare-coin-art.cjs --check` performs the same validation without changing
files. `tools/build-web.cjs` requires this preflight before Godot import; missing,
changed, incorrectly sized or lossy coin inputs stop the build with the rebuild
commands. There is no optional-asset fallback for a coin release.

The build receipt tracks the manifest, texture inputs, preparation source and
validator. Final pack verification requires both correctly sized coin textures.
The export explicitly excludes the Python authoring script, source manifest and
review contact sheet; the pack verifier also rejects their presence, including
an imported copy of the review sheet. The deployed art credits identify the
source creator, license and gold adaptation.

The actual source and processed contact sheet were inspected. The review includes
24, 32, 40 and 48 pixel HUD sizes on the game's pale background, plus every angle
on a dark background. The ring detail remains readable at 24 pixels, while 32px
or larger better preserves the metal highlights. All four edges are transparent
and free of a rectangular matte. Integrated captures check the chest burst, flight,
arrival and settled balance at 1000 x 800, 390 x 844, 320 x 568 and 568 x 320.
Lifecycle tests verify arrival-gated counting, persistence and interrupted flights.
