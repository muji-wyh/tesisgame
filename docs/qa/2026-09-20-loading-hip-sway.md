# Grounded loading Pip hip sway

The old dance moved the whole torso sideways and lifted each foot on every
beat. The revised dance keeps both outside toes anchored, rocks only the
unweighted heel, and moves the hips further than the shoulders. The head and
wings follow slightly later. A small squash during the weight transfer and
rise at each accent replace the rigid left/right pose changes.

Two wing raises lead into four hip-sway cycles. The 12-beat loop takes 5.28
seconds; its curves are sampled once and played by six browser animations.
There is no per-frame JavaScript. Tap reactions and loader cleanup are unchanged.

## Verification

- All 17 wardrobe and Web-export Node checks passed.
- The release Web build passed pack verification, including 200 pronunciations
  and eight slice sounds, with zero missing resources (14.95 MB startup).
- All 27 targeted loading cases passed across desktop Chromium and iPhone/iPad
  WebKit profiles: full dance cycle, saved outfits, three tap reactions, rapid
  taps, responsive layouts, reduced motion, page lifecycle and entry cleanup.
  WebKit uses Windows device emulation, not physical Apple hardware.
- Nine browser-rendered frames were inspected across one 880 ms hip cycle.
  The hat, clothes, wing roots and body/foot overlaps remain connected at both
  extremes. The body bends without sliding the feet.
- SVG-coordinate measurements keep the left toe at (24, 110) and the right toe
  at (99, 111). The waist moves from x=52.84 to x=69.16 while the shoulder stays
  between x=59.09 and x=62.91.

Preview evidence: `build/pip-hip-sway-preview/hip-contact-sheet.png` and
`build/pip-hip-sway-preview/motion.json`.

The actual local export also passed the trajectory, tap, audio and entry checks
without an engine fixture. Both toe drift measurements were below 0.0001 SVG
units; shoulder X range was 3.82 versus 16.32 at the hips. No JavaScript errors
were reported. Screenshots of both sway extremes were inspected.

Browser evidence: `build/voice-pop-qa/loading-hip-sway-browser` and
`build/voice-pop-qa/loading-hip-sway-local`.
