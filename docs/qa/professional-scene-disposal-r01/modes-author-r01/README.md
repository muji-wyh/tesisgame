# Professional mode disposal probe

Prepared on 2026-10-17. No parser, test, native runtime, build, or export was executed by this author. The coordinating agent owns execution. The frozen original Match disposal test is unchanged.

`tests/godot/professional_scene_modes_disposal_tests.gd` extends the existing disposal fixture and exercises Memory, Phrase, Pop, Jelly, and Word Jelly in the real main scene. Each case opens one synthetic reviewed Professional round through the real session/native store, starts a replacement, holds its media completion, and queues scene deletion.

Before deletion, the probe captures weak references to every scene node. At active-lease release, it inspects their actual resource properties and nested array/dictionary values, including AtlasTexture sources. Capturing nodes in advance keeps detached or queued-for-deletion children observable. Exact unique copies of existing sourced picture/audio assets identify consumer references; the media provider's RefCounted cache is intentionally not treated as a view consumer. The fixture assets remain test-only and do not establish curriculum/media approval.

Jelly receives a real arriving batch through `game.drop_now`, producing landing projections before pending replacement pauses it. The release trace records those surviving node weak references and their textures. Pop warms its real canvas texture cache without starting speech. Each case silently retains a scoped stream in the real AudioStreamPlayer. The probe requires zero consumer references before release, exactly one active release, dead cache/resource weak references after deletion, revoked scoped URLs, and unchanged snapshot bytes.

A small publisher fake is injected only into the main UI after all native setup. Store and loader transports remain unchanged. It records UI publisher methods and rejects calls during subtree teardown, including the final parent exit callback. Calls before actual exit are annotated separately because Godot may drain legitimate deferred work before processing `queue_free`. The probe also checks the original Play publication guards.

This test covers the five views' resource lifecycle and terminal callbacks. It does not repeat their gameplay suites or claim new visual, audio, browser, packaging, or curriculum approval. Synthetic catalog theme artwork is empty; the picture/audio checks exercise scoped lesson media.

`test-source.gd.txt` freezes the authored test. `inputs.json` records its inputs and current production hashes for review; the parent must bind execution to its final production preimages. `inventory.json` hashes the other artifacts and excludes itself.
