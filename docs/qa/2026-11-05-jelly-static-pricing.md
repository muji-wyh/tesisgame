# Jelly World static merge pricing

## Scope and policy

Validated the working-tree pricing change against base revision
`ccf771e3f548ef3154612071f50858a6ad9d0348` on 2026-11-05.

Auto Merge and pending word-goal family merge now charge 25 coins for the
first successful use, 50 for the second, and 75 for every later use in a round.
Auto Merge has its own counter; all word-goal families share a separate counter.
A new round resets both counters. Quantity, owned Auto Merge level, capacity,
and board reduction do not change these prices. Rejected, duplicate, unavailable,
or failed purchases do not advance a counter. Historical paid receipt amounts
remain unchanged.

Generic price and model snapshot reads no longer populate merge previews or
simulate the automatic merge timeline. Purchase validation works with a cold
preview cache. Family availability metadata and hover forecasts still evaluate
legal merges where needed.

## Native regression evidence

Twelve focused suites passed:

| Suite | Passing checks |
| --- | ---: |
| `coin_economy_tests` | 2,283 |
| `word_jelly_model_tests` | 121,153 |
| `word_jelly_auto_merge_upgrades_tests` | 836 |
| `word_jelly_pricing_flow_tests` | 24 |
| `word_jelly_selected_merge_flow_tests` | 183 |
| `word_jelly_powerup_flow_tests` | 190 |
| `word_jelly_fill_items_tests` | 1,581 |
| `word_jelly_funds_feedback_tests` | 13 |
| `word_jelly_powerup_availability_tests` | 140 |
| `word_jelly_controls_tests` | 1,251 |
| `word_jelly_selected_merge_tests --pricing-only` | 657 |
| `word_jelly_merge_pricing_cache_tests` | 722 |

Coverage includes the price cap, round reset, exact debit, insufficient funds,
duplicate requests, successful-use counters, cold-cache purchase validation,
and fixed prices across quantities and owned levels. Moving-arrival fixtures
read prices and full model snapshots over 24 frames at owned Lv1 and Lv9 with
zero preview, simple-planner, or forecast calls. Hover prediction behavior is
also retained.

The full selected-merge suite has one independently reproduced existing failure:
`Later main stages actually dispatch more often and land faster, not merely report harder catalog metadata`.
The candidate reported 727 checks and one failure; the exact base model and
original tests reported 725 checks and the same failure. The failing assertion
belongs to `test_main_pressure` and its late-stage motion-speed expectation.
The focused pricing subset passes; the full selected-merge suite is not a clean
pass.

Local logs are under `build/performance/chrome-60fps/`:

- `static-merge-pricing-regressions-v1.log`
- `static-merge-pricing-regressions-v2.log`
- `static-merge-pricing-regressions-v3.log`
- `static-merge-pricing-selected-baseline-v1.log`

## Browser Fill diagnosis

Built `build/performance/jelly-static-pricing-fine-v1/` using the existing
19-probe diagnostic harness. Captured a real Fill operation from the 14-body
opening in headed Chrome Canary 159.0.8140.0 at 1366 x 768, with normal motion
and audio, an eight-second excluded warmup, and a six-second sample.

Evidence is in `build/performance/jelly-static-pricing-fine-capture-v1/`.
Of 50 sampled process frames, 23 contained moving bodies. Those moving frames
recorded 23 live model steps and zero forecast steps, with no merge-preview,
powerup-forecast, or finish-powerup probe entries. The scenario reached 56
settled bodies without an error, purchase, merge, or collection. Peak decorative
animation ownership remained three while up to 23 bodies moved physically.

The earlier same-probe Fill capture recorded 22 forecast steps during 22 moving
frames. This verifies removal of the pricing-driven forecast workload. One
instrumented capture does not establish a stable speedup or a 60 FPS result.
The host uses Hyper-V/SwiftShader and its empty-page baseline is approximately
30 FPS; diagnostic probes add overhead and their nested timings overlap.

This section records the pre-release local diagnostic export. It does not
describe the production export or establish production frame-rate acceptance.

## Production release validation

`npm run build:web` succeeded with zero native pack-verification failures.
`node tools/web-build-receipt.cjs --verify` then confirmed that 14,127 source
inputs and 117 output files remained unchanged. This is the normal production
export, without diagnostic instrumentation.

Three targeted desktop browser cases passed with one worker and zero retries,
using headed Chrome Canary and normal motion/audio on the actual export:

- Owned Lv4 Auto Merge retains its six-output cap and overlapping launch
  rhythm, charges exactly 25, and advertises 50 next while family merge stays 25.
- A word-goal family purchase preserves unrelated families, charges exactly
  25, and advances every family's quote to 50 while Auto Merge stays 25.
- A 15-coin wallet reports the exact 10-coin shortfall without spending,
  merging, changing either successful-use counter, or changing either quote.

The maintained cases select a 1473 x 1175 desktop viewport. They are functional
purchase/feedback regressions, not physical frame-rate acceptance. The affected
browser expectations for Lv2 gameplay were also updated to the same static
first-use policy; its complete upgrade journey was not rerun in this release.

Build and browser evidence is retained under `build/performance/chrome-60fps/`:

- `release-static-pricing-build-v1.log`
- `release-static-pricing-browser-v1.log`
- `release-static-pricing-browser-v1.json`
- `release-static-pricing-browser-v1/`

Publishing uses `npm run deploy -- -SkipBuild`, which revalidates the same
production receipt before uploading. The post-deployment delivery check
compares the online index, engine JavaScript, and decoded game pack with the
local export, and checks HTTP availability of its versioned WebAssembly. Its
release-specific output is
`build/performance/chrome-60fps/release-static-pricing-production-verification-v1.json`.
