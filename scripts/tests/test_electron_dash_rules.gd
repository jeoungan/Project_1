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
	if not _check(Rules.LANE_COUNT == 5, "default panel count is five"):
		return

	if not _check(Rules.wrap_lane(0, -1, 12) == 11, "left wraps to final lane"):
		return
	if not _check(Rules.wrap_lane(11, 1, 12) == 0, "right wraps to first lane"):
		return

	var default_segment := Rules.make_segment(0)
	if not _check(default_segment["floors"].size() == 5, "default segment has five floor panels"):
		return
	if not _check(default_segment["lasers"].size() == 5, "default segment has five laser lanes"):
		return
	if not _check(default_segment["unstable"].size() == 5, "default segment has five unstable flags"):
		return
	if not _check(default_segment["hearts"].size() == 5, "default segment has five heart lanes"):
		return

	var five_lane_gap_a: Array = Rules.make_segment(6, 5)["floors"]
	var five_lane_gap_b: Array = Rules.make_segment(7, 5)["floors"]
	if not _check(five_lane_gap_a.find(false) != five_lane_gap_b.find(false), "five-panel gaps vary by segment"):
		return

	var heart_segment := Rules.make_segment(11, 5)
	var heart_lane: int = heart_segment["hearts"].find(true)
	if not _check(heart_lane >= 0, "heart pickups appear in the corridor"):
		return
	if not _check(Rules.segment_has_floor(heart_segment, heart_lane), "heart pickup sits on a floor"):
		return

	for index in range(Rules.SAFE_START_SEGMENTS, Rules.SAFE_START_SEGMENTS + 30):
		if not _check(Rules.segment_has_safe_lane(Rules.make_segment(index, 5), 5), "generated segment remains avoidable"):
			return

	var safe_segment := Rules.make_segment(0, 12)
	for lane in range(12):
		if not _check(Rules.segment_has_floor(safe_segment, lane), "safe start floor exists"):
			return

	var danger_segment := {
		"floors": [true, false, true],
		"lasers": [false, true, false],
		"unstable": [false, false, true],
		"hearts": [false, false, false]
	}
	if not _check(Rules.should_crash(danger_segment, 1, true, false), "grounded player crashes on missing floor"):
		return
	if not _check(Rules.should_crash(danger_segment, 1, true, false), "laser hits when grounded"):
		return
	if not _check(Rules.should_crash(danger_segment, 1, false, false), "laser still hits while airborne"):
		return
	if not _check(Rules.should_crash(danger_segment, 2, true, false), "unstable panels collapse under grounded player"):
		return
	if not _check(Rules.speed_for_distance(1000.0) > Rules.speed_for_distance(0.0), "speed rises with distance"):
		return

	print("test_electron_dash_rules passed")
	quit(0)
