# Bramble, the Jelly World compass thief

## Character

- Original: **Bunny** from [Low Poly Monsters Pack / product 380750](https://assetstore.unity.com/packages/3d/characters/low-poly-monsters-pack-380750).
- Acquired archive: **50+ Monsters Bundle**, **Wabu**, 1.0. The listing subsequently
  identified Visible Ghost / 1.1; this is the same product, not a second acquisition.
  The discrepancy and original package hash remain in
  [the retained source record](../../docs/assets/talk-quest-monsters.json).
- License: **Standard Unity Asset Store EULA**. The acquired FBX and converted
  reusable GLB remain private. Only the compiled game embeds them.
- Source FBX SHA-256:
  `981a92e69550d090ab08d55bc8eb8d26fac406fa35be5807025496cd29115705`.
- Original source preview was inspected: complete white/purple rabbit, ears,
  original carrot prop, nonthreatening face, no skull imagery or aggressive teeth.
  This preview is not a gameplay screenshot or proof of animated integration.
- Conversion: `tools/prepare-jelly-boss.py` preserves Bunny/Carrot mesh topology,
  original diffuse materials and the actual source rig. Four strongest
  skin influences are normalized by the glTF exporter.
- Integrated build input: `private/bramble.glb`; its exact size and SHA-256 are
  recorded by the converter in `manifest.json`.
- Available converted clips: `Idle`, `Throw`, `Kick`, `Snatch`, `Hit`, `Taunt`,
  `Celebrate`, `Escape`. These eight clips are **game-authored skeletal motion**,
  not relabeled publisher clips. Actual native renders and desktop/phone browser
  journeys review deformation, extreme poses, the front face and phone framing.
  Conversion alone is not substituted for those presentation checks.
  The revised `Taunt` poses the original upper arms and uses each posed parent's
  transform to aim bent forearms into a playful raised-hand stance. This is an
  authored rival gesture, not a newly acquired publisher animation. The tall
  transparent battle viewport keeps the full body beside the board; its camera
  includes the extreme hand poses rather than clipping them into a HUD portrait.

Talk Quest remains retired. This reuses one separately acquired character, not
the old mode, monster roster, environments, or gameplay.

## Map portrait

The Boss map marker is a real transparent portrait of Bramble, not a text capsule.
`tools/render-jelly-boss-portrait.gd` samples the integrated model's authored
`Idle` at 0.45 seconds, preserves the complete face and ears, and proportionally
fits the actual rendered upper-body image into a 256-pixel transparent canvas.
It is a static in-game portrait, distinct from the original source-listing preview.
Creator and license are the same Wabu / Standard Unity Asset Store EULA recorded
above. The image and import metadata remain private build inputs; `manifest.json`
records their model-source hash, image hash, dimensions and acquisition status.

Regenerate after restoring the acquired model:

```powershell
node tools\run-godot.cjs --path . --rendering-method gl_compatibility --script res://tools/render-jelly-boss-portrait.gd
```

The portrait is also a touch target for its unlocked stage. The stage numeral and
earned stars remain separate; locked future portraits cannot start a stage.
Stage 1 deliberately has no portrait marker or watching-visitor presentation
before its actual story ambush.
The stage-99 exception enlarges that same acquired portrait and frames it with
the acquired Kenney medallion and Archanor rays, tinted dark purple. It is an
in-game finale marker, not a new character acquisition or horror redesign.

## Interface and effects

The lock and eye-closed marks reuse the existing Tabler SVG controls (MIT);
countdown artwork reuses the acquired Fluent Emoji 3D clock. Existing attribution
is in `assets/images/ui/ATTRIBUTION.md`. One and two individual padlock images
distinguish the two lock levels; a progress arc is interface geometry, not a
replacement character or effect asset.

The stolen Word Compass reuses the inspected, integrated Microsoft Fluent Emoji
3D compass (Microsoft Corporation, MIT), not a newly invented treasure image.
The exact source and adaptation hashes remain in
`docs/assets/word-library.json`, entry `compass`.
Its unchanged bytes are copied to `assets/jelly-boss/compass.webp` so the Boss
story starts before the separate age-twelve vocabulary pack is mounted.

Magic trails, anticipation, thaw and unlock bursts reuse the already acquired
Bobardo portal texture and Archanor Toon FX rays/sparkles. Source identities,
licenses and private-input handling remain in
[Jelly level feedback](../../docs/assets/jelly-level-feedback.md).
These are static production textures with game-authored trajectories.
The eight health-energy glints, hit depletion, side-dock light and retreat
accents reuse these exact textures. There is no replacement geometric character,
opaque battle information panel or board-sized ending dialog.

The current pursuit pass keeps the compass visible beside Bramble throughout a
rematch and enlarges the same source during the theft and final return. Short
game-authored, two-line challenges identify his actual tricks and the next
encounter; no dialogue is relabeled as recorded speech. Idle, Hit and Escape
retain the same acquired rig and authored clips. The visible word bolt's 550 ms
contact now drives the hit cue, small grounded recoil and local energy loss
together; the final strike gets its victory accent before the concession and
retreat. These are presentation/sequence changes, not additional damage,
rewards, source animation, character geometry or audio acquisitions.

## Boss vocalization

- **Evil Laugh**, recorded/performed by **AntumDeluge** for Stendhal.
- Original listing and CC0 declaration:
  <https://opengameart.org/content/evil-laugh>.
- Acquired original:
  <https://opengameart.org/sites/default/files/laugh-evil-1_0.ogg>.
- Integrated as `assets/audio/jelly-boss/bramble-laugh.ogg`, unchanged source
  bytes, SHA-256
  `2662d484fd3f174145de1ac7527994d153b109ff8f1ee3ac83591beec58d62e4`.
- **CC0 1.0**, mono Vorbis, 44,100 Hz, 2.544240 seconds, 28,146 bytes.
  Source mean level is -18.3 dBFS; runtime gain is 0.28. This is an acquired
  human vocal performance, not an oscillator or substitute spoken word.
- Dialogue is game-authored, readable English subtitle exchange. The laugh is
  a character vocalization; the subtitle sentences are not claimed to be fully
  voiced recordings. Existing mute, speech ducking and pause cleanup apply.

Throw, hit, kick, repair and victory cues reuse the existing acquired Kenney
fragment/chest bank; no combat announcement insulting the learner is included.
