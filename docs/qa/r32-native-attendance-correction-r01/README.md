# Attendance historical native comparison correction

R32 retained **249/249 passing Node tests**, **141/0 native audio checks**, and
**2,837 native morphology checks with one failure**. All 679 measured inputs and
the registry stayed unchanged during that run. The failing assertion compared
the current attendance entry directly with a protected historical preimage,
without reversing the subsequently accepted attendance language update.

The correction changes only
`tests/godot/professional_retail_morphology_tests.gd`. It requires exactly one
scoped attendance language patch, verifies that the complete current entry equals
the accepted `after` entry, then deep-copies `before` for the existing historical
comparison. The exact protected snapshot comparison, pending morphology checks
and resolver behavior remain. It does not omit attendance, loosen comparisons,
alter historical evidence or change any production data.

The focused corrected native run passed **2,839 checks with zero failures**.
All 679 measured inputs stayed unchanged during the run. Comparison against R32
allows only the exact native-test insertion, and separately verifies that the
accepted attendance preimage equals the protected donor and its morphology is
unchanged. Registry SHA256 remains
`8574160412f2cdbb0e3891421f995ded387f108fd2727d66eb13fd83d2959a67`.

The [focused receipt](receipt.json) has SHA256
`87eb0fbefbf573c68fbd06f7c539a11c1c3c2b7fe1913b31a62bf994476013db`.
The [failed R32 receipt](continuation-validation-r32.json) has SHA256
`951167226fbfa4e362dbb415146385785fdc682115e0591b28e3cb30f81253d9`.
Both original logs, the native-test preimage, the harness and its frozen
execution input inventory are retained here as exact copies from
`build/professional-english/r32-native-attendance-correction-r01/` and the R32
validation paths. These are completed execution records; do not replay them.

R32 is still a failed historical run. This focused correction supplements it;
it does not relabel R32 as passing or claim a fresh full-suite run. Passing Node
and audio suites were not repeated because their inputs did not change. No
browser, performance, complete-game or full-module acceptance is implied.
