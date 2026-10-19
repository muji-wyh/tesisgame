extends "res://tests/godot/professional_play_tests.gd"

const OriginalPlay = preload("res://build/professional-english/professional-play-reentrancy-r01/preimages/scripts/professional_play.gd")
const EVIDENCE: String = "res://build/professional-english/professional-play-reentrancy-r01/"
var current_checks: Array = []


func check(condition: bool, message: String) -> void:
	super.check(condition, message)
	current_checks.append({"check": message, "passed": condition})
	var file: FileAccess = FileAccess.open(EVIDENCE + "current-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 1, "checks": current_checks, "count": checks,
		"failures": failures, "scope": "Actual ProfessionalPlay controller with controlled lifecycle callbacks, actual Access registry, and retained real initial-storage recovery test; no domain integration or acceptance."}, "  ") + "\n")
	file.close()


func _run() -> void:
	var original: Array = _reentrancy_probes(OriginalPlay, true)
	var broken: int = 0
	for row: Dictionary in original:
		if not row.passed:
			broken += 1
	var file: FileAccess = FileAccess.open(EVIDENCE + "original-reproduction.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 1, "source": "saved exact preimage", "count": original.size(),
		"invariant_failures": broken, "checks": original,
		"scope": "Historical failing observations only; not counted as a passing current suite. Four empty-pending historical paths are excluded to avoid intentional engine aborts."}, "  ") + "\n")
	file.close()
	print("Historical controller replay: %d observations, %d invariant failures (saved preimage only)" % [original.size(), broken])
	await super._run()
