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
	if not _check(default_segment["movers"].size() == 5, "default segment has five moving obstacle flags"):
		return
	if not _check(default_segment["jump_markers"].size() == 5, "default segment has five jump warning flags"):
		return
	if not _check(not default_segment.has("hearts"), "segments do not spawn collectibles"):
		return

	var seeded_gap_a: Array = Rules.make_segment(10, 5, 1001)["floors"]
	var seeded_gap_b: Array = Rules.make_segment(10, 5, 2002)["floors"]
	if not _check(seeded_gap_a != seeded_gap_b, "seed changes generated map layout"):
		return

	var continuous_segment: Dictionary = Rules.make_segment(Rules.SAFE_START_SEGMENTS + 1, 5, 1001)
	if not _check(continuous_segment["floors"].find(false) == -1, "non-jump segments keep the road continuous"):
		return
	var long_gap_lane: int = -1
	for lane in range(5):
		if not Rules.segment_has_floor(Rules.make_segment(10, 5, 1001), lane) and not Rules.segment_has_floor(Rules.make_segment(11, 5, 1001), lane):
			long_gap_lane = lane
	if not _check(long_gap_lane >= 0, "jump-gap hazards span multiple rows"):
		return
	if not _check(Rules.segment_has_jump_marker(Rules.make_segment(9, 5, 1001), long_gap_lane), "jump warning appears before long gap"):
		return

	for index in range(Rules.SAFE_START_SEGMENTS, Rules.SAFE_START_SEGMENTS + 30):
		var generated_segment: Dictionary = Rules.make_segment(index, 5, 1001)
		if not _check(not generated_segment.has("hearts"), "generated segments stay collectible-free"):
			return
		if not _check(generated_segment["lasers"].find(true) == -1, "generated segments do not use laser blockers"):
			return
		if not _check(generated_segment["unstable"].find(true) == -1, "generated segments do not use vanishing tiles"):
			return
		if not _check(Rules.segment_has_safe_lane(generated_segment, 5), "generated segment remains avoidable"):
			return

	var mover_segment: Dictionary = Rules.make_segment(22, 5, 1001)
	if not _check(mover_segment["movers"].find(true) >= 0, "moving rectangular obstacles appear on the road"):
		return

	var safe_segment := Rules.make_segment(0, 12)
	for lane in range(12):
		if not _check(Rules.segment_has_floor(safe_segment, lane), "safe start floor exists"):
			return

	var danger_segment := {
		"floors": [true, false, true],
		"lasers": [false, true, false],
		"unstable": [false, false, true],
		"movers": [false, false, false],
		"jump_markers": [false, false, false]
	}
	if not _check(Rules.should_crash(danger_segment, 1, true, false), "grounded player crashes on missing floor"):
		return
	if not _check(Rules.should_crash(danger_segment, 1, false, false), "laser still hits while airborne if present"):
		return
	if not _check(Rules.should_crash(danger_segment, 2, true, false), "unstable panels collapse under grounded player"):
		return
	var mover_danger_segment := {
		"floors": [true, true, true],
		"lasers": [false, false, false],
		"unstable": [false, false, false],
		"movers": [false, true, false],
		"jump_markers": [false, false, false]
	}
	if not _check(Rules.should_crash(mover_danger_segment, 1, true, false), "moving obstacle hits its lane"):
		return
	if not _check(Rules.speed_for_distance(1000.0) > Rules.speed_for_distance(0.0), "speed rises with distance"):
		return
	if not _check(Rules.speed_for_distance(0.0) <= 13.0, "starting speed is slower and readable"):
		return
	if not _check(is_equal_approx(Rules.speed_for_distance(0.0), 12.0), "speed starts at twelve"):
		return

	print("test_electron_dash_rules passed")
	quit(0)
