# Talk Quest guardian replacement review

> Archived on 2026-10-06. Talk Quest has been removed from the game. This
> document preserves the former implementation, source provenance, and review
> evidence. Its asset paths, interfaces, and commands describe that revision;
> they are not current build prerequisites or instructions to restore the mode.
> Retained manifests and license records do not mean the runtime assets ship.

Reviewed on October 2, 2026. This is a source shortlist, not the active game
roster. The new direction is large, attractive, friendly fantasy guardians.
The earlier frightening creature shortlist was rejected.

All fourteen source listings allow free download under CC BY 4.0. Official
preview images and public metadata are saved locally. The actual model
archives have not been downloaded: Sketchfab requires sign-in for the official
download. Nothing in this shortlist has been imported or deployed.

The review is available at `http://127.0.0.1:41774/monster-refresh.html` while
the local asset review server is running. Its files live under
`C:/uworks/TalkQuest/asset-review`. The source evidence is retained in
`C:/uworks/TalkQuest/sources/monster-friendly-research.json` and
`C:/uworks/TalkQuest/sources/monster-friendly-additions.json`.

## Proposed assignments

Names and giant scale are proposed presentation choices. Animation counts are
the number listed by the hosting service, not verified game-ready actions.

| Level | Proposed guardian | Original source and creator | Listed animations |
| --- | --- | --- | --- |
| 1 | Riku the Welcomer | [Baby Dragon RIKU](https://sketchfab.com/3d-models/608f023dc57f46c89af93cb5a051b3f0) by BlueMesh | 1 |
| 2 | Golden Brookkeeper | [Free Low Poly Cartoon Koi Fish](https://sketchfab.com/3d-models/62ea29193ca14f7fb65c5876bfc2ea66) by GameAssetsFin | 6 |
| 3 | Honeywing | [Cute Dragon](https://sketchfab.com/3d-models/df14ec74767c4598920132758dab8a49) by shakiller | 1 |
| 4 | Rosemane | [Just a Unicorn!](https://sketchfab.com/3d-models/8d0ae2d4b1ac4d1f8ab2adcdcc01cc8f) by nottodayrender | 4 |
| 5 | Maple Guardian | [Red Panda](https://sketchfab.com/3d-models/c003c2985e0e462684063a893a0e85ee) by kenchoo, original model by EonSculpts | 1 |
| 6 | Professor Feather | [Owl](https://sketchfab.com/3d-models/d177e1fbcce940cba32e434cc5a62f1a) by po | 1 hosted; publisher describes 9 motions |
| 7 | Orchard Crown | [Fantasy Deer](https://sketchfab.com/3d-models/eaabaf7ee4aa46b7b58cf9aed891960d) by July | Static |
| 8 | Storykeeper Fox | [Wizard Fox](https://sketchfab.com/3d-models/f5466d5aef0f4c50951789de3aaa66be) by 3dtoad | Static |
| 9 | Moonlit Unicorn | [Unicorn](https://sketchfab.com/3d-models/ca0cb9a7a3144853ac6e4158d6b4e468) by janexx | Static |
| 10 | Windmill Wanderer | [Turtle House Worldskills 2022](https://sketchfab.com/3d-models/7a0d72ec1c034de397c8ef30f54e0049) by ryanwilliams510 | Static |
| 11 | Starlight Swimmer | [Whale Shark Fantasy](https://sketchfab.com/3d-models/451892c9c18c4d74bf893bea8b626b02) by Alenzo | 6 |
| 12 | Crownfire Companion | [The cute dragon](https://sketchfab.com/3d-models/0d74e0eb9c12471bbed7ea64601eef3e) by Morzilah | Static; explicitly no rig |
| 13 | Velvet Wayfarer | [Rabbit Traveler](https://sketchfab.com/3d-models/09c2cbcda7884490a7b927acd14f2ca1) by SamTheCaribbean | Static |
| 14 | The Great Skywhale | [Mythic Whale](https://sketchfab.com/3d-models/124137f938ec4f5390ddde6dffd7c62e) by Meleagors | 1 |

## Remaining integration work

- Inspect all source animations for friendly faces and reactions. Eight
  listings include animation; six are static and need rigging and motion.
  The gallery's Skywhale 3D embed was opened successfully; this does not verify
  complete clip playback or engine compatibility.
- Remove the rabbit's sheathed sword. Confirm the downloaded geometry permits
  a clean edit before accepting that source for the game.
- Preserve both creators' credits for the red panda derivative. The white
  unicorn listing also contains separately credited environment and music;
  exclude those extras unless their licenses are checked individually.
- Optimize high-density sources for mobile, check textures and rig conversion,
  and compose each guardian at actual phone size. The owl and koi use simpler
  stylized source designs; their final visual consistency still needs review.
- Use the actual models and source materials, following the
  [asset art direction](art-direction.md). Do not replace unacquired creatures
  or missing effects with shape or color placeholders.
