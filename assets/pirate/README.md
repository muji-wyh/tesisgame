# Game-ready Pirate

Pirate is the active Jelly World Boss in tesisgame's GL Compatibility renderer.
Open `res://scenes/pirate_asset_preview.tscn` to inspect the model and all actions.
The supplied game-ready pack replaces Bramble in battle, on map markers, and in
the finite Game over performance. Its source model and animation files match
`Q:/uwok/boss/game-ready/tesisgame-pirate-pack.zip` as supplied on 2026-11-05.

`scripts/word_jelly_boss_actor.gd` adapts the 22 native clips to the existing
combat clock. Freeze, ink and lock use light, medium and heavy attacks. Jelly
levels 1-3, 4-6 and 7-9 select the corresponding hit strength at visual contact.
Sky attacks use Giant Ram; grabbing a word uses Big Bite; storm events rotate
the three ultimates. Ordinary taunts rotate the ten authored gestures. A new
record receives a hat tip rather than the ordinary belly laugh.

The adapter poses object pivots manually, clamps one-shots at their end, and
projects body and hat landmarks for effects. It does not invent a Frog skeleton.
The existing combat rules, saved campaign identities and sourced audio cues
remain under their original owners. Reference-image creator and license remain
unknown as recorded in `SOURCE.md`; no third-party rights are inferred.

Files:

- `pirate-game.glb`: self-contained optimized character with 22 node animations and four expression morphs.
- `pirate-portrait.png`: transparent 256 x 256 portrait from the optimized model.
- `manifest.json`: provenance, measured budgets and animation contract.
- `optimization-report.json`: detailed final glTF audit.
- `SOURCE.md`: source and acquisition details.
- `taunt-designs.json`: gesture, expression, duration and inspection time for each taunt.

The original twelve clip names are `Idle`, `Attack_L`, `Attack_M`, `Attack_P`, `Hit_L`,
`Hit_M`, `Hit_P`, `Ultimate_TidalRush`, `Ultimate_CrescentSpin`,
`Ultimate_CaptainsDrop`, `Special_GiantRam` and `Special_BigBite`.
L, M and P mean light, medium and heavy. Idle loops; the other clips are one-shots.
Each clip begins and finishes at rest and explicitly resets `Bite_Open`,
`Eye_Squint`, `Smile_Smirk` and `Tongue_Out` to zero. Giant Ram grows the body
while the hat keeps its shape. Crescent Spin completes two full turns.

The ten taunts add distinct one-shot gestures. Their facial expressions deform
the actual eye, smile and tongue geometry in the same elastic body mesh.

| Clip | Duration | Gesture |
| --- | --- | --- |
| `Taunt_HatTip` | 1.5 s | Rigid hat tip and wink |
| `Taunt_BellyLaugh` | 2.1 s | Three uneven laugh pulses |
| `Taunt_SideEye` | 1.7 s | Slow side turn and held smirk |
| `Taunt_NopeWag` | 1.5 s | Three alternating refusals |
| `Taunt_Peekaboo` | 2.0 s | Hat advances, lowers over the eye and reveals it twice |
| `Taunt_MockBow` | 2.0 s | Theatrical bow and cheeky rise |
| `Taunt_Swagger` | 2.1 s | Two lateral hops with opposite lean |
| `Taunt_TongueTease` | 1.8 s | Rounded tongue extends and retracts |
| `Taunt_VictoryLap` | 2.5 s | One full orbiting turn and hat salute |
| `Taunt_FakeSleep` | 2.6 s | Tilted doze and a startled wake-up |

The HTML and native preview expose a Taunts category. The glTF audit checks the
four weights separately, all neutral resets, exact timings and distinct
normalized gesture trajectories. Full `Bite_Open` remains exclusive to
`Special_BigBite`; the teasing mouth openings stay partial.

Use the reusable actor in `scripts/pirate_asset_actor.gd` to normalize the subject
to two units high without changing its internal animated pivots. glTF front is +Z
and up is +Y. The preview has a generous fixed camera for the full motion envelope;
the portrait uses tighter whole-character framing.

Pirate has no skeletal bones and does not implement Bramble's `Throw`, `Kick`,
`Snatch`, `Taunt`, `Celebrate` or `Escape` actions. Use an explicit gameplay mapping
and authored effect anchors when selecting Pirate for a stage. Do not send legacy
Frog bone names or animation names to this actor.

Rebuild from the preserved authoring folder in PowerShell:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --threads 8 --python Q:/uwok/boss/animation_library.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --threads 8 --python tools/optimize-pirate.py
python tools/pack-pirate-gltf.py
node tools/build-pirate-preview.mjs
node tools/run-godot.cjs --headless --path . --import
node tools/run-godot.cjs --headless --path . --script res://tools/validate-pirate-asset.gd
node --test tests/pirate-asset.test.cjs
node tools/run-godot.cjs --path . --rendering-method gl_compatibility --script res://tools/render-pirate-qa.gd
python tools/record-pirate-manifest.py
```

The optimizer writes temporary output beneath `build/pirate` and an editable
optimized blend beneath `Q:/uwok/boss/game-ready`. The full authoring blend stays
separate from the optimized derivative. `Q:/uwok/boss/taunt_library.py` authors
the ten taunt timelines and the additional expression morphs.
The offline HTML preview is written to `Q:/uwok/boss/game-ready/index.html`.
The browser viewer needs Three.js/esbuild installed in the authoring folder only
at build time. Godot uses the GLB directly.

The runtime ZIP keeps the repository's asset, script, scene, tool and test
layout, with an offline HTML preview and captured PNGs under `preview/qa`.
Its QA report retains the original repository capture paths and their hashes.
Rebuilding still uses the separately preserved authoring folder described above.

Keep `pirate-game.glb.import` and `pirate_import.gd` with the model. The import
profile skips unused tangents. The asset-specific import hook converts glTF's
linear vertex colors to sRGB storage for Compatibility and enables those colors
on every colored material surface. Materials declare the resulting sRGB encoding
for linear renderers. Converted meshes carry an encoding marker, so the actor's
fallback cannot convert them twice. The original GLB color data remains unchanged.

Generated LODs are disabled only for this roughly 10,000-triangle asset: Godot's
public ArrayMesh API does not expose the LOD arrays needed for a color-only mesh
rebuild. Positions, normals, indices, blend-shape mode and all expression morph arrays,
surface materials/names, and shadow mesh are retained. Native QA requires an
actual rendering backend; headless mode is used only for import and state checks.
