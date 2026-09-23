# Medals page removal — 2026-09-24

## Scope

More opens Pip's room directly. The Medals tab, shelves, next-medal panel,
reward preview, and their navigation routes have been removed. World choices,
age choices, toys, chest rewards, fragment progress, and toy unlocks remain.
Existing favorite medals stay as static room decorations; saved reward,
favorite, backdrop, and sticker records retain their formats and values.

The removal also exposed a keyboard-focus scrolling issue: the scroll helper
tracked Pip's layout slot as the focused object. It now tracks Pip while
revealing the slot through deferred layout updates. A regression starts with
Pip fully offscreen and verifies that focus reveals his body and jumping head.

## Validation

- 20 relevant Godot suites: **3,386 assertions passed**, including 74 removal
  checks. Coverage includes missing retired routes, responsive layouts,
  keyboard/controller return, saved favorites, a third chest piece unlocking
  its toy, Try it with Pip, persistence, and room focus/scrolling.
- Web export and playroom host Node tests: **17 passed**.
- Web export succeeded; the exported startup pack passed resource verification.
- Browser tests use the actual exported Godot game and run serially.

| Browser coverage | Result |
| --- | --- |
| World switching, save retry, migrated favorites and backdrop | 6 passed across desktop Chromium and iPhone/iPad WebKit profiles |
| Pip/toy interaction and room dragging | 6 passed across the same profiles |
| Direct room entry, static title, no retired help text, owned toys and reload | 3 passed across the same profiles |
| Four reward rounds, toy unlock and reload; Voice Pop pause/resume through More | 2 passed on desktop Chromium |

All **17 selected browser scenarios** passed in their final runs.

The initial iPhone removal run stalled in the loader on reload. Its unnecessary
fixture route was replaced with a conditional local-storage initialization,
preserving normal browser caching. The final removal test then passed on all
three browser profiles without retries.

Desktop and 320-pixel portrait screenshots were visually checked. These are
Playwright browser profiles, not physical-device testing.

Local evidence is under `build/medals-removal-browser/`, with logs named
`build/medals-removal-browser-*.log` and
`build/medals-removal-export-final.log`.
