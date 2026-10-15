# Windows WebKit canvas presentation after resizing

The previously recorded Jelly resize failure remains an external browser-runtime
limitation. On October 15, 2026, a standalone WebGL 2 canvas reproduced it without
Godot, game code, a server, loaded assets, or network requests. Chromium presents
the same canvas correctly. No production renderer or gameplay workaround was
introduced.

## Reproduction and result

Run either diagnostic from the repository root with the installed Playwright
browsers:

```powershell
node tools/diagnose-webgl-resize.cjs --browser chromium
node tools/diagnose-webgl-resize.cjs --browser webkit
```

The script continuously clears sixteen colored strips in an ordinary WebGL 2
canvas, using an iPhone 13 device profile. It captures the composed page and the
raw canvas before resizing from 390 x 664 to 320 x 568, immediately after, and
after another 3.1 seconds. Reports and both images are retained under
`build/webgl-resize-diagnostics/<browser>/`.

| Runtime on Windows | Initial page / canvas colors | Resized page / canvas colors | After 3.1 seconds | Exit |
| --- | --- | --- | --- | --- |
| Chromium 153.0.8010.12, Playwright 1.63.0 | 16 / 16 | 16 / 16 | 16 / 16 | 0 |
| WebKit 26.6, Playwright 1.63.0 | 16 / 16 | 1 / 16 | 1 / 16 | 1 |

The WebKit page image is uniformly white while its raw image still contains all
sixteen strips. Both runtimes report correctly resized drawing buffers, no lost
context, no WebGL error, and no page errors. The diagnostic deliberately returns
a failure for blank composed output; raw-canvas success does not turn that into
a pass. Images from both WebKit outputs were visually inspected.

## Relation to the game

The existing game export reproduces the same signature: its composed page drops
from 271 sampled colors to one after resizing, while the raw canvas continues
to render 480 colors. The framebuffer and viewport both become 960 x 1704,
with no graphics error or context loss. Evidence is retained in
`build/resize-diagnostics.json` and the associated captures.

Targeted experiments did not recover presentation: CSS compositing hints,
opacity and display changes, reinserting the same canvas, `gl.finish()`, an
alpha-enabled context, and disabling drawing-buffer preservation. The standalone
case also fails with multisampling disabled and with width/height updates split
over separate animation frames. These experiments were isolated from production.

This evidence isolates the failure to the Windows Playwright WebKit presentation
path. It does not establish whether physical iPhone/iPad Safari has the same
problem, and fixed-size WebKit passes do not resolve live resizing. A page reload
would discard the active game and a mirrored canvas would introduce a separate
renderer, so neither is used to conceal the failure. Re-run the standalone
diagnostic after a browser-runtime update before treating resize validation as
passed.
