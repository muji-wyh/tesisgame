# Empty Web search regression

## Reproduction and root cause

The immutable `build/tests/learning-r2/export` browser capture passed all twenty
exact career-title searches and the no-match query. Selecting the entire query
and pressing Backspace then showed the empty search placeholder, but the career
list retained zero rows for the complete ten-second assertion window. Evidence:
`build/tests/learning-r2/run-home-desktop.log` and the `trace.zip` and failure
screenshot in its `results-home-desktop/learning-paths-both-paths--bac24-able-before-media-downloads-desktop-chromium`
directory. The screenshot confirms that the actual rendered list was stale;
this was not only an outdated accessibility snapshot.

The local runtime identifies itself as Godot
`4.7.stable.official.5b4e0cb0f`. The matching upstream source was inspected:

- [DisplayServerWeb keyboard callback](https://github.com/godotengine/godot/blob/4.7-stable/platform/web/display_server_web.cpp)
  forwards the HTML input's complete text with signal emission enabled.
- [Window input-text callback](https://github.com/godotengine/godot/blob/4.7-stable/scene/main/window.cpp)
  forwards that request to the viewport.
- [Viewport text dispatch](https://github.com/godotengine/godot/blob/4.7-stable/scene/main/viewport.cpp)
  dynamically calls the focused control's `_set_text(text, emit_signal)` method.
- [LineEdit replacement implementation](https://github.com/godotengine/godot/blob/4.7-stable/scene/gui/line_edit.cpp)
  calls `clear_internal()` before reading `previous_text`. When the replacement
  is empty, its comparison therefore finds no difference and omits
  `text_changed` even though the previous user-visible query was nonempty.

Copies of those exact inspected source files are retained in the ignored
`build/tests/search-clear` review directory. No engine binary or exported capture
was changed.

## Correction

Both career search and the professional module word library use
`scripts/search_line_edit.gd`. The subclass receives the same dynamic Web text
dispatch and calls the original native method. It supplements a notification
only when emission was requested, the text actually changed, and the native
signal revision did not advance. Normal native editing and silent assignments
retain their existing behavior. If a later Godot version correctly sends the
empty-input signal, the revision check prevents a duplicate notification.

No polling, synthetic browser input, alternate filtering algorithm, or gameplay
state change was added.

## Verification

Before the correction, a native regression invoking the exact Web method with
`_set_text("", true)` reproduced the bug: **310 checks, 1 failure** in the
learning-path selector suite. It did not manually emit `text_changed`.

After the correction:

- Learning-path selector: **316 checks, 0 failures**. This covers nonempty
  replacement, restoration of all twenty careers on clear, one notification
  per change, unchanged empty text, silent nonempty/empty replacements, and a
  subsequent nonempty query.
- Professional word library: **131 checks, 0 failures**. The real Web method
  filters the ambiguous `bank` senses by definition, reaches no results, then
  restores all fifty terms and the bounded eight-row first page on clear.

Real browser verification passed against immutable r3, receipt
`2026-10-15T18:41:13.729Z`. The desktop Chromium batch passed both cases: all
twenty title queries plus no-match/clear (4.0 minutes), and dedicated empty-search
regression with final-character deletion and unchanged empty text (58.1 seconds).
Both used the real focused HTML input and keyboard, and neither requested course
media or produced page errors. All nine snapshotted inputs stayed unchanged.
Evidence: `build/tests/learning-r3/run-search-desktop.log`,
`results-search-desktop.json`, and `search-desktop-source/{before,after}.json`.
All four path-screen captures were inspected at 320 x 568, 390 x 844,
844 x 390 and 1280 x 800: labels and actions fit, with stacked portrait cards
and side-by-side landscape/desktop cards.

The r3 mobile batch subsequently passed both iPhone WebKit search cases: clear
and final-character deletion (45.1 seconds), and the browser text-input bridge
with reduced visible viewport (51.3 seconds). The iPhone saved-theme/Sound/motion
case also passed (122.2 seconds). All nine before/after input hashes matched.
Android search cases did not run because the preceding saved-theme scenario
reached its 300-second overall budget. That failure occurred while traversing
Home controls after reload, not in a search assertion. Android search remained
unverified at that checkpoint. Preserve the failed scenario and its trace separately from the three
iPhone passes. Evidence: `build/tests/learning-r3/results-mobile-search-sound.json`,
`run-mobile-search-sound.log`, and `mobile-search-sound-source/`.
Emulation does not establish physical-device keyboard behavior.
The old r2 failure remains failed evidence and the r2 capture stays immutable.

## Targeted Android follow-up

The r4 Android follow-up passed all three cases with one worker and no retries: saved Sound after reload (105.0 seconds), empty-query and final-character restoration (63.4 seconds), and touch input bridge with reduced viewport (75.9 seconds). The focused Sound case reaches the real control through reverse keyboard navigation, verifies the muted state after reload, then toggles it back. The original long forward-navigation scenario remains a preserved timeout. Inspected screenshots show Sound: off and the HR search result within the reduced viewport. Nine source inputs, three harness files and117 immutable r4 export outputs retained their hashes. No page/test errors were reported. Evidence: build/tests/learning-r4-android-v2/review.md, results.json, run.log, before.json, after.json and the two result PNGs. The first Android harness failed during discovery and launched no browser; its separate failure record remains preserved. Physical-device OS keyboard behavior remains unverified.
