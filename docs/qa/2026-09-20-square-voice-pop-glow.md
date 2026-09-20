# Square Voice Pop listening glow

The viewport glow now meets at right-angle corners. Four full-length edge strips
replace the rounded corner tiles and radial corner masks. The narrow inward fade,
breathing rhythm, moving highlights and reduced-motion behavior are retained.
The decorative overlay remains pointer-transparent and hides when listening ends.

## Verification

- 48 speech-host tests passed.
- The Web export passed startup-pack verification, including all eight imported
  hit sounds and 200 word pronunciations: zero failures, 14.95 MB startup.
- Six browser cases passed: 320x568 and 844x390 on desktop Chromium, iPhone WebKit
  and iPad WebKit profiles. They cover listening, target hits, reduced motion,
  input passthrough and hiding the glow on mode exit.
- Actual animated/static screenshots were reviewed: square viewport corners,
  continuous color, no bright corner hotspots and unobstructed game controls.

Speech recognition is simulated; no physical microphone was opened. WebKit runs
as Windows device emulation, not on physical Apple hardware.

Evidence: `build/voice-pop-qa/square-voice-pop-glow`.
