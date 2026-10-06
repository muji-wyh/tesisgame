# Interface typography

Nunito by the Nunito Project Authors is acquired from the Google Fonts repository.

- Source: https://github.com/google/fonts/tree/main/ofl/nunito
- Upstream: https://github.com/googlefonts/nunito
- License: SIL Open Font License 1.1, retained in [OFL.txt](OFL.txt).
- Acquired file: `Nunito.ttf`, the original `Nunito[wght].ttf` variable font.
- SHA-256: `bb55a5ca5c2042335b3991af27c4d0705d0ef41cac6164ac737fd8f2a1e85207`.
- Integration: local body and heading resources use weights 600 and 850. No remote
  font request is required while playing. This is a font, with no animation.

The browser shell embeds static weight 600 and 800 instances (`Nunito-600.ttf`
and `Nunito-800.ttf`). Windows WebKit rendered the original variable font at its
200 default even with an explicit CSS axis; static instances were visually
verified in Chromium and WebKit. The original font's outlines and license remain
intact. The instances were generated with FontTools 4.61.1:

```python
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
for weight in (600, 800):
    font = TTFont("Nunito.ttf", recalcTimestamp=False)
    instantiateVariableFont(font, {"wght": weight}, inplace=True, updateFontNames=True)
    font.save(f"Nunito-{weight}.ttf")
```

The game library reuses acquired Twemoji cat, rainbow, and rocket artwork under
the [existing CC BY 4.0 attribution](../avatars/ATTRIBUTION.md).
The original vector files are reused without modification. These
are integrated static illustrations; no character animation is claimed.
