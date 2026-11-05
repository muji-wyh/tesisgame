# Bramble, the Jelly World compass thief

Bramble is retained as an archived acquired asset. The active Jelly World Boss
is now the user-supplied optimized Pirate pack, documented in
[Pirate's source record](../pirate/SOURCE.md) and [integration record](../pirate/README.md).

## Character

- Original: **Frog** from [Low Poly Monsters Pack / product 380750](https://assetstore.unity.com/packages/3d/characters/low-poly-monsters-pack-380750).
- Acquired archive: **50+ Monsters Bundle**, **Wabu**, 1.0. The listing subsequently
  identified Visible Ghost / 1.1; this is the same product, not a second acquisition.
  The discrepancy and original package hash remain in
  [the retained source record](../../docs/assets/talk-quest-monsters.json).
- License: **Standard Unity Asset Store EULA**. The acquired FBX and converted
  reusable GLB remain private. Only the compiled game embeds them.
- Source FBX SHA-256:
  `b716387a7be20268652e64b36aff88a8a46169ed8401051b422bebdacf00af76`.
- Original source previews for Cactoro, Frog and Squidle were inspected.
  Frog was selected for its broad face, large expressive hands, friendly mouth
  and complete articulated body, without skull imagery or exposed teeth.
  The original Frog preview is yellow with dark spots; it is not the final
  mint-jade/cream game material.
  This preview is not a gameplay screenshot or proof of animated integration.
- Conversion: `tools/prepare-jelly-boss.py` preserves the 2,532-vertex Frog mesh
  topology and actual source rig. A game-authored mint-jade skin and cream
  belly/spot finish lighten its silhouette; the original mouth stays dark and
  the eye surfaces retain their source materials. Four strongest
  skin influences are normalized by the glTF exporter.
- Integrated build input: `private/bramble.glb`; its exact size and SHA-256 are
  recorded by the converter in `manifest.json`.
- Available converted clips: `Idle`, `Throw`, `Kick`, `Snatch`, `Hit`, `Taunt`,
  `Celebrate`, `Escape`. These eight clips are **game-authored skeletal motion**,
  not relabeled publisher clips. Original-eye morphs `Blink.L`, `Blink.R` and
  `WideEyes` add real blinks, a one-eye taunt and a wide-eyed impact reaction.
  The facial tracks are exported in those same eight clips, not separate fake
  animation names. The source FBX contains 43 action records; the retained
  `lpm-frog` inventory in `docs/assets/talk-quest-monsters.json` includes its
  evaluated `IdleStanding1` and `YesStanding` takes. Those publisher actions
  are not relabeled or claimed as the new Boss performance.
  `Taunt` uses actual finger bones and raised, forward-facing palms rather than
  Bunny's ear motion. The existing foot-control IK remains baked for grounded
  kicks and retreat. Conversion is separate from native pose, face and framing
  review; earlier Bunny browser evidence does not verify this replacement.

The previous Bunny and carrot are no longer the active Boss model. Talk Quest
remains retired. This reuses one separately acquired character, not
the old mode, monster roster, environments, or gameplay.

## Map portrait

The Boss map marker is a real transparent portrait of Bramble, not a text capsule.
The retired portrait tool sampled the integrated model's authored
`Idle` at 0.45 seconds, preserves the complete face and ears, and proportionally
fits the actual rendered upper-body image into a 256-pixel transparent canvas.
It is a static in-game portrait of the converted Frog face and shoulder silhouette,
distinct from the original source-listing preview.
Creator and license are the same Wabu / Standard Unity Asset Store EULA recorded
above. The image and import metadata remain private build inputs; `manifest.json`
records their model-source hash, image hash, dimensions and acquisition status.

Regenerate after restoring the acquired model:

```powershell
# Historical Bramble capture command retired; active Pirate QA uses tools/render-pirate-qa.gd.
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

Narrow gameplay layouts retain the word goals on the left and reuse this same
full-body rig in a footer dock to the right of the actions. Wider layouts keep
the existing right-side dock. Aspect-preserving framing, the eight clips,
actual-board attack anchors and the same acquired energy effects remain intact;
this is responsive placement, not another model or animation acquisition.

The difficulty pass reuses the existing sourced-rendered doubles for one
visible opening decoy at stage 9 and two at stage 99. The final encounter has
1,400 health; paid Jelly damage and charge/combo multipliers are unchanged.
No invisible opening shield, new effect asset or instant untelegraphed attack
is added. The ordinary anticipation, attack ownership and eight clips remain.

The current pursuit pass keeps the compass visible beside Bramble throughout a
rematch and enlarges the same source during the theft and final return. Short
game-authored, two-line challenges identify his actual tricks and the next
encounter; no dialogue is relabeled as recorded speech. Idle, Hit and Escape
retain the same acquired rig and authored clips. The visible word bolt's 550 ms
contact now drives the hit cue, small grounded recoil and local energy loss
together; the final strike gets its victory accent before the concession and
retreat. These are presentation/sequence changes, not additional damage,
rewards, source animation, character geometry or audio acquisitions.

## Saved Game over performance

The saved Jelly World failure modal reuses that same acquired private Frog GLB
and its existing game-authored two-second `Taunt`, not a portrait replacement,
publisher animation relabel, new download or procedural character. The rig's
actual `Middle1.L` and `Middle1.R` palm-base joints drive local acquired
Bobardo portal glow and Archanor sparkles. Those effects remain static source
textures with game-authored trajectories, not a new particle-pack acquisition.
The gesture, wink and hand-light peak share one short presentation clock.

Nine native samples from 0.0 through 1.99 seconds were inspected for the full
face, hands, fingers and feet. Their union in the 384-by-576 viewport is
`(16, 151, 338, 344)`. The UI uses a padded GPU atlas region
`(4, 139, 362, 368)` to remove transparent camera margins without flattening
the actual animated rig. Runtime does not read the viewport back into an image.
The source-pose contact sheet is review evidence, separate from the integrated
phone and desktop Game over captures.

One 2.4-second visual response then holds a relaxed open-hand pose; it does not
replay its burst while the player decides. Reduced motion samples the real
one-second wink once with a still soft light. Backgrounding or leaving stops
the viewport, and repeated wallet/result refreshes retain the same round clock.
The saved retry, upgrade and map actions never wait for the performance.
An earned Challenge record retains its medal and positive acknowledgement.
Storage errors and voluntary exits do not trigger this response.

The new modal layer deliberately adds no second vocalization or fully voiced
line. Existing combat, defeat and record audio keep their established ownership
and mute controls; the short English captions are game-authored text.
Creators, licenses, acquisition status and all eight available converted clips
remain the character/effect records above.

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
