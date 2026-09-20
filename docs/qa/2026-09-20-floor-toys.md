# Playable toys throughout Pip's home

All earned toys now appear as full-size objects on the playable floor, with
their vocabulary words underneath. The shelf is removed. The active toy is
rendered once alongside the other earned toys; selecting one keeps its floor
position. Only locked toys remain in the catalog below, and that catalog hides
when all nine toys are earned.

One tap on an inactive toy saves the selection and immediately plays its first
action. A drag selects and throws it in the same gesture. Keyboard/controller
activation also starts play, with both the object and its complete word kept
visible. Locked previews, save retries, and the existing three-step actions
remain available. The first tap during scroll inertia stops scrolling; the next
tap plays the toy. An unearned saved selection falls back to one visible ball.

## Native verification

Final targeted runs passed **1,733 assertions**, with zero failures:

| Suite | Assertions |
| --- | ---: |
| Playroom view | 315 |
| Direct playground input | 199 |
| Collection navigation | 163 |
| Gift adventure | 138 |
| Card polish | 239 |
| Room scrolling | 17 |
| UI recovery | 36 |
| Legacy saves | 60 |
| Goal text | 400 |
| Audio flow | 106 |
| Expansion | 60 |

Direct-input coverage taps every earned toy with mouse and touch, checks one
pronunciation/action per tap, and drags inactive toys through completed throws
without an extra tap or collection scroll. Other checks cover ownership changes,
duplicate prevention, complete vocabulary labels, failed-save recovery, and
preservation of medals, collected words, and lesson state.

The initial audio expectation assumed selection alone stayed silent. It was
migrated to verify the exact flower pronunciation stream and first action stage,
matching the new immediate-play behavior. Empty-floor input fixtures were also
moved clear of the newly clickable word labels. Regression checks now cover the
fixes for scroll inertia and the duplicate fallback ball.

## Web and visual acceptance

`npm run build:web` passed. The startup pack checked 200 word pronunciations
and 174 optional paths without failures; the packaged startup download is
14.95 MB with 87 on-demand audio assets.

Browser regression passed **31 cases**, zero failures, across desktop Chromium
and emulated iPhone/iPad WebKit. Two WebKit touch-drag cases are explicitly
skipped because trusted touch motion uses Chromium CDP; mouse drag passes in
all three profiles and touch drag passes in Chromium.

```powershell
$env:POP_BASE_URL = 'http://127.0.0.1:4173'
$env:POP_QA_LABEL = 'floor-toys-browser'
npx playwright test tests/browser/owned-toys-home.spec.cjs tests/browser/card-polish.spec.cjs tests/browser/gift-adventure.spec.cjs tests/browser/expansion.spec.cjs --config build/voice-pop.config.cjs --grep 'toys live|locked preview returns|inactive floor toy|failed-load retry|earned saved goal|starter toy remains|Pip and Words'
```

Actual canvas screenshots under `build/voice-pop-qa/floor-toys-browser/` were
inspected for desktop partial/complete ownership, iPhone partial/complete
ownership and preview/save recovery, and iPad complete ownership. Earned toys
appear directly on the floor at the apple's scale, with readable vocabulary
underneath and no shelf or duplicate selection strip. The floor extends when
needed; only locked toys remain in the lower catalog. Mobile profiles are
browser emulation, not physical-device tests.

The screenshot review found that the keyboard focus border crossed the first
line of a save-error caption. Both active and inactive toy error captions now
start below the 64px sprite target; the existing 239-check polish suite passes
again with both lines inside the floor. The final rebuilt export passed all
**6** active/inactive save-error browser cases across the three profiles. The
320px active-ball and iPhone inactive-flower screenshots were inspected again:
both retry lines now remain below the focus outline and inside the room.
Follow-up evidence is under `build/voice-pop-qa/floor-toys-error-polish/`.

## Production acceptance

Runtime commit `d064487` was merged into `main`, pushed to GitHub and deployed
to https://gentle-forest-02ff42900.3.azurestaticapps.net/.

All four production startup files match the final tested export by SHA-256.
Sizes and hashes are recorded in
`2026-09-20-floor-toys-production-manifest.json`.

Real production Chromium acceptance passed **9 / 9** cases with zero browser
errors: 390x844, 768x1024 and 1366x768, each with starter (1 owned / 8 locked),
partial (3 / 6) and complete (9 / 0) ownership. Each partial case also verifies
first-tap play, keyboard continuation, locked-preview return, failed-save
recovery, and mouse/touch dragging of an inactive toy into a completed throw.
All cases preserve the player's earned medal data.

Production screenshots of the complete phone/tablet floor, the desktop partial
home, and a phone apple throw were inspected. Evidence and per-case reports
are under `build/voice-pop-qa/floor-toys-production/`. Test saves exist only in
isolated browser contexts and do not modify an existing player's browser save.
