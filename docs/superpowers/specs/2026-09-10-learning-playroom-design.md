# Word Buddies: learn, practise, play

The user asked for a plan followed by implementation, commit and deployment. This design improves the word–picture association and turns rewards into playable objects. The existing Godot browser runtime remains; Unity CLI is an asset import tool.

## Learning experience

- Add a first-class **Learn** view, initially selected, alongside Match, Sky and Listen. Show one large, unmistakable picture with its written word, a Hear button, previous/next controls, progress through the five-word lesson, and Play Match. Audio remains gesture initiated.
- A lesson contains the same five words across Learn and all three quiz modes. Switching modes resets the attempt, preserves the lesson and world, and cancels stale feedback. A new adventure explicitly chooses another lesson. Repeat lesson intentionally retains the words.
- Preserve the existing three-mistake challenge and one medal fragment per completed quiz; Learn browsing never awards fragments. The user has an optional question pending about unlimited supported practice; until they choose it, retain the established challenge rules.
- Replace rushed feedback with a large picture + correct written word + Hear + Continue presentation. Wrong Match attempts distinguish the selected word and selected picture; an orphan card is explained as having no partner. Quiz answers remain locked until continuation. Voice automation must resolve its feedback without swallowing queued speech or blocking indefinitely; voice mode can retain its existing timed flow while showing the same correct association.
- Show visible instructions. Keep only short instructions near the playfield; put teaching detail in the Learn/feedback view.
- Review all five lesson words after an attempt, with missed words first. Provide Repeat lesson and New adventure. Describe words as practised, never claim mastery from one answer.
- Listen must show the target word visibly when sound is unavailable or playback fails, so the picture question remains answerable.
- Never offer these overlapping labels against each other: earth/planet, acorn/seed, boot/shoe, shell/clam, flower/rose, comet/meteor. If a custom pool has no safe distractor, show an explicit unavailable state rather than a misleading question.

## Artwork and Unity assets

- Fix recognisability of spoon, towel, coat, arm, leg, milk, head, berry, shell/clam and comet/meteor using the existing original-art generators where suitable.
- Unity Asset Store research found **Food Icons Pack**, Angelina Avgustova, package 70018: 100 hand-drawn transparent 256px PNG food icons, free, Standard Unity Asset Store EULA. Evaluate its actual downloaded images before choosing replacements; exclude objects that do not match the vocabulary or age range.
- The public GitHub repository must not redistribute the complete licensed source pack. Keep the downloaded package, staging Unity project and restricted imported art outside tracked source; commit the extraction/import tool, explicit mappings, provenance and licence requirements. Use the art in the compiled game. Preserve original-art fallbacks for developers without the licensed pack.
- Unity CLI must actually import the selected art through the installed Unity Editor using a fresh ignored staging project. Check archive paths first, retain only necessary art/metadata/licence content, and avoid executing third-party Editor scripts. Export/copy only the used image/audio data into Godot.
- Record source URL, package version, file hashes, import command, selected assets and validation evidence. Do not claim this requirement complete before a real package is downloaded, imported by Unity CLI and visible in the deployed game.

## Pip's room

- Preserve existing medals, fragments, legacy rewards and favourite medal.
- Introduce a room preview with a toy slot and backdrop slot. Starter ball is playable immediately. Each world's first complete medal unlocks its toy (flower, ball variant, apple, bell, shell, rocket); its third complete medal unlocks that world's backdrop.
- Owned items are derived from validated medal progress, not a second reward currency or guessed learning history. Show locked items with artwork, a name and a concrete requirement.
- Toys have distinct actions (water the flower, roll the ball, offer an apple, ring the bell, listen to the shell, launch the rocket), an animated response from Pip, and pronunciation of their familiar noun. Interactions are repeatable and do not alter medals. Reduced motion keeps visible static outcomes.
- Save selected toy, selected backdrop and favourite in one versioned playroom record. Migrate the existing favourite. Browser saves stay synchronous; failed or corrupt saves remain explicit and retryable. Never replace medal progress.
- Show a named next gift with remaining pieces. Announce a newly unlocked gift after its claim is successfully saved and offer Try it with Pip.

## Verification and delivery

Native checks cover stable lesson identity, same-word mode switches, explicit continuation, missed-word ordering, semantic exclusions, audio fallback, unlock thresholds, migration and failed writes. Browser checks cover real visible associations, usable controls, scrolling/focus, tiny and tablet layouts, reduced motion and immediate reload. Inspect actual rendered pages and imported illustrations.

Run the appropriate complete native/Node suite, build the Godot web export, test changed browser flows and affected existing flows. Commit, integrate into main, push and deploy through the existing Azure script. Verify the live game pack hash and live Learn/quiz/room behavior before completion.
