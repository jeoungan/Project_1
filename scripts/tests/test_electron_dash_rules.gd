extends SceneTree

const Rules := preload("res://scripts/electron_dash/electron_dash_rules.gd")

func _fail(message: String) -> void:
	printerr(message)
	quit(1)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		_fail(message)
		return false
	return true

func _initialize() -> void:
	if not _check(Rules.wrap_lane(0, -1, 12) == 11, "left wraps to final lane"):
		return
	if not _check(Rules.wrap_lane(11, 1, 12) == 0, "right wraps to first lane"):
		return

	var safe_segment := Rules.make_segment(0, 12)
	for lane in range(12):
		if not _check(Rules.segment_has_floor(safe_segment, lane), "safe start floor exists"):
			return

	var danger_segment := {
		"floors": [true, false, true],
		"lasers": [false, true, false]
	}
	if not _check(Rules.should_crash(danger_segment, 1, true, false), "grounded player crashes on missing floor"):
		return
	if not _check(Rules.should_crash(danger_segment, 1, false, false), "laser hits when not ducking"):
		return
	if not _check(not Rules.should_crash(danger_segment, 1, false, true), "ducking avoids laser while airborne"):
		return
	if not _check(Rules.speed_for_distance(1000.0) > Rules.speed_for_distance(0.0), "speed rises with distance"):
		return

	print("test_electron_dash_rules passed")
	quit(0)
