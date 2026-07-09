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
	if not _check(default_segment["blocked_markers"].size() == 5, "default segment has five blocked gap warning flags"):
		return
	if not _check(not default_segment.has("hearts"), "segments do not spawn collectibles"):
		return

	var seeded_gap_a: Array = Rules.make_segment(Rules.JUMP_GAP_FIRST_SEGMENT, 5, 1001)["floors"]
	var seeded_gap_b: Array = Rules.make_segment(Rules.JUMP_GAP_FIRST_SEGMENT, 5, 2002)["floors"]
	if not _check(seeded_gap_a != seeded_gap_b, "seed changes generated map layout"):
		return

	var continuous_segment: Dictionary = Rules.make_segment(Rules.SAFE_START_SEGMENTS + 1, 5, 1001)
	if not _check(continuous_segment["floors"].find(false) == -1, "non-jump segments keep the road continuous"):
		return

	var jump_gap_lane: int = Rules.jumpable_gap_lane_for_segment(Rules.JUMP_GAP_FIRST_SEGMENT, 5, 1001)
	if not _check(jump_gap_lane >= 0, "jumpable gap lane is generated"):
		return
	for row_offset in range(Rules.JUMPABLE_GAP_ROWS):
		var gap_segment: Dictionary = Rules.make_segment(Rules.JUMP_GAP_FIRST_SEGMENT + row_offset, 5, 1001)
		if not _check(not Rules.segment_has_floor(gap_segment, jump_gap_lane), "jumpable gap keeps its lane empty for configured rows"):
			return
	var landing_segment: Dictionary = Rules.make_segment(Rules.JUMP_GAP_FIRST_SEGMENT + Rules.JUMPABLE_GAP_ROWS, 5, 1001)
	if not _check(Rules.segment_has_floor(landing_segment, jump_gap_lane), "road reconnects after a jumpable gap"):
		return
	for marker_index in range(Rules.JUMP_GAP_FIRST_SEGMENT - Rules.JUMP_WARNING_ROWS, Rules.JUMP_GAP_FIRST_SEGMENT):
		var jump_marker_segment: Dictionary = Rules.make_segment(marker_index, 5, 1001)
		if not _check(Rules.segment_has_jump_marker(jump_marker_segment, jump_gap_lane), "jump marker covers the whole jump-start window"):
			return
	var early_jump_marker_segment: Dictionary = Rules.make_segment(Rules.JUMP_GAP_FIRST_SEGMENT - Rules.JUMP_WARNING_ROWS - 1, 5, 1001)
	if not _check(not Rules.segment_has_jump_marker(early_jump_marker_segment, jump_gap_lane), "jump marker starts only when the gap becomes reachable"):
		return

	var blocked_gap_lane: int = Rules.blocked_gap_lane_for_segment(Rules.BLOCKED_GAP_FIRST_SEGMENT, 5, 1001)
	if not _check(blocked_gap_lane >= 0, "unreachable gap lane is generated"):
		return
	for row_offset in range(Rules.BLOCKED_GAP_ROWS):
		var blocked_gap_segment: Dictionary = Rules.make_segment(Rules.BLOCKED_GAP_FIRST_SEGMENT + row_offset, 5, 1001)
		if not _check(not Rules.segment_has_floor(blocked_gap_segment, blocked_gap_lane), "unreachable gap is longer than the jumpable gap"):
			return
	for marker_index in range(Rules.BLOCKED_GAP_FIRST_SEGMENT - Rules.BLOCKED_WARNING_ROWS, Rules.BLOCKED_GAP_FIRST_SEGMENT):
		var blocked_marker_segment: Dictionary = Rules.make_segment(marker_index, 5, 1001)
		if not _check(Rules.segment_has_blocked_marker(blocked_marker_segment, blocked_gap_lane), "red marker covers the unjumpable gap approach"):
			return
		if not _check(not Rules.segment_has_jump_marker(blocked_marker_segment, blocked_gap_lane), "unreachable gaps use red markers instead of jump markers"):
			return
	if not _check(Rules.BLOCKED_GAP_ROWS > Rules.JUMP_CLEAR_ROWS, "unreachable gaps exceed one-jump distance"):
		return
	if not _check(Rules.JUMP_GAP_CYCLE <= 14, "jump gaps are spaced more tightly"):
		return
	if not _check(Rules.BLOCKED_GAP_FIRST_SEGMENT - Rules.JUMP_GAP_FIRST_SEGMENT <= 7, "blocked gaps arrive closer after jump gaps"):
		return
	if not _check(Rules.EXTRA_GAP_CYCLE <= 3, "extra missing tiles are generated frequently"):
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

	var missing_tile_count: int = 0
	var mover_count: int = 0
	for index in range(Rules.SAFE_START_SEGMENTS, Rules.SAFE_START_SEGMENTS + 42):
		var difficulty_segment: Dictionary = Rules.make_segment(index, 5, 1001)
		for has_floor in difficulty_segment["floors"]:
			if not bool(has_floor):
				missing_tile_count += 1
		if difficulty_segment["movers"].find(true) >= 0:
			mover_count += 1
	if not _check(missing_tile_count >= 36, "generated maps have dense missing blocks"):
		return
	if not _check(mover_count >= 10, "generated maps have dense moving obstacles"):
		return

	var mover_segment: Dictionary = Rules.make_segment(63, 5, 1001)
	if not _check(mover_segment["movers"].find(true) >= 0, "moving spike obstacles appear on the road"):
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
		"jump_markers": [false, false, false],
		"blocked_markers": [false, false, false]
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
		"jump_markers": [false, false, false],
		"blocked_markers": [false, false, false]
	}
	if not _check(Rules.should_crash(mover_danger_segment, 1, true, false), "moving obstacle hits its lane"):
		return
	if not _check(Rules.speed_for_distance(1000.0) > Rules.speed_for_distance(0.0), "speed rises with distance"):
		return
	if not _check(Rules.speed_for_distance(0.0) >= 14.0, "starting speed is faster"):
		return
	if not _check(is_equal_approx(Rules.speed_for_distance(0.0), 14.0), "speed starts at fourteen"):
		return

	print("test_electron_dash_rules passed")
	quit(0)
