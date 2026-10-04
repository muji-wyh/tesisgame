# Talk Quest: The Word Isles

The map now uses a consistent miniature archipelago palette: three prepared
chapter skies, distant islands, original source clouds, a winding stone route,
and paper destination plaques. The current island has a blue flag and warm
plaque. Plain-language replay and prerequisite captions make progress visible
without relying only on color. The journey footer shows all fourteen stops and
returns to the first unfinished island without starting an encounter.

The existing acquired Kenney models and Poly Haven environment remain the
source artwork. No new marketplace previews or procedural substitute scenery
were integrated. Sky preparation and the distinction between prepared and
actually displayed decorations are recorded in the map's source record.

## Native verification

- Atlas: 1,750 checks passed, including all fourteen destinations at ten
  size/scale combinations, pointer inertia, locked input, keyboard focus,
  cancellation, current-island navigation, and source textures.
- Compact Quest layout: 117 checks passed.
- Quest scene: 693 checks passed.
- Asset, Web export, deployment, and Quest host contracts: 88 Node tests passed.

The full main scene produced twenty renderer captures across 1280 x 800,
390 x 844, 844 x 390, and 320 x 568. Each size includes a fresh journey,
progress at island seven, a saved encounter, the final locked destination,
and all islands explored. Local evidence is under `build/quest-map-page/`.
The harness isolates and removes temporary player saves.

Visual inspection found two regressions during development. A 258-pixel-high
map retained a tall heading and footer, leaving almost no island artwork; the
short layout now reserves space for scenery and puts labels beside islands.
Completing the final island with reduced motion could leave an old footer
count; progress changes now request a redraw independently of scrolling.
The regression test failed before the redraw fix and passed afterward.
Chapter titles refit after both scrolling and viewport changes.

## Web verification

The final Web build passed the exported-pack resource checks and contains
33.12 MB of startup downloads. Both browser cases passed in desktop Chromium
and iPhone WebKit: traversing all fourteen destinations through portrait,
landscape, and portrait again; and using region navigation and Your island
after desktop, phone, and landscape resizing. The navigation checks confirm
that progress stays unchanged and no encounter or microphone session starts.

The initial WebKit return check observed a chapter update before the native
scroll layout had settled. It now waits for the complete current island to
enter the viewport, rather than treating a chapter update as proof of layout
completion. Both browser projects passed the corrected check.

Actual exported-canvas captures were inspected. Route captures remain under
`test-results/`; the final navigation captures are under
`build/word-isles-browser-navigation/`. Windows WebKit can retain an old page
compositor image after resizing; the raw game canvas was also captured and
verified directly.

These checks use desktop rendering and browser emulation. They do not establish
physical mobile performance or live microphone/audio quality; no audio or
combat rules were changed in this presentation work.
