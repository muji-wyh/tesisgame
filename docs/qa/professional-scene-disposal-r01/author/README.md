# Real scene disposal probe

Prepared on 2026-10-17. No parser, native test, build, or export was executed by this author. The coordinating agent owns execution and any production correction.

`tests/godot/professional_scene_disposal_tests.gd` instantiates the real main scene with the established player-flow fixture. Only the curriculum owner/catalog and media transport/cache are synthetic. It opens one Professional Match round through the real session and native store, then queues scene deletion during a held replacement policy, media request, or dispatched storage registration. Each case uses an isolated user-data directory.

The probe records actual exit order and observes the active cache lease release. It requires Match textures, the library picture, and the professional stream retained by the real audio player to be cleared before that lease is released. The stream is loaded through the scoped resolver without playback so the test is silent. The source picture and sound are unique copies of existing sourced repository assets; they are fixture resources, not proposed curriculum artwork.

It also requires no Play publications after subtree teardown begins, terminal store closure, no result from the retained host callback after closure, disconnected request timers, unchanged primary/previous/pending bytes, revoked scoped URLs, exactly one active lease release, and dead scene/cache/resource weak references after deletion. The storage case sends its held callback during the main scene's final tree-exiting signal, after child terminal guards but before child destruction, then checks that its target becomes invalid after deletion.

Expected source-level regression: `game_ui._ready` builds controls and collection before adding ProfessionalPlay. Godot exits sibling subtrees in reverse insertion order. Therefore the current Play exit releases its active scope while earlier view/audio children still retain resources. The new assertions are deliberately not weakened to accept that ordering. The owner double also retires during its exit, matching the production owner and making teardown publications observable. These are expected failures pending execution, not claimed runtime findings.

Godot ordering reference: [Node::_propagate_exit_tree in the Godot source](https://raw.githubusercontent.com/godotengine/godot/4.4/scene/main/node.cpp). The [Node queue_free documentation](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-queue-free) explains why the fixture holds completions instead of assuming queued deletion precedes deferred work.

The saved test-source copy and input hashes bind this prepared probe. `inventory.json` hashes the other files in this directory and excludes itself. The parent may execute `godot --headless --path <worktree> --script res://tests/godot/professional_scene_disposal_tests.gd` using its established runtime and record stdout/stderr separately.
