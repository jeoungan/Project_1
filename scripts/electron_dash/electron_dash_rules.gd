class_name ElectronDashRules
extends RefCounted

const LANE_COUNT: int = 5
const SAFE_START_SEGMENTS: int = 6
const JUMP_CLEAR_ROWS: int = 7
const JUMPABLE_GAP_ROWS: int = 5
const JUMP_WARNING_ROWS: int = JUMP_CLEAR_ROWS - JUMPABLE_GAP_ROWS
const BLOCKED_GAP_ROWS: int = JUMP_CLEAR_ROWS + 1
const BLOCKED_WARNING_ROWS: int = JUMP_WARNING_ROWS
const JUMP_GAP_FIRST_SEGMENT: int = SAFE_START_SEGMENTS + 4
const JUMP_GAP_CYCLE: int = 14
const BLOCKED_GAP_FIRST_SEGMENT: int = JUMP_GAP_FIRST_SEGMENT + 7
const BLOCKED_GAP_CYCLE: int = JUMP_GAP_CYCLE
const EXTRA_GAP_FIRST_SEGMENT: int = SAFE_START_SEGMENTS + 8
const EXTRA_GAP_CYCLE: int = 3
const LONG_GAP_FIRST_SEGMENT: int = BLOCKED_GAP_FIRST_SEGMENT
const LONG_GAP_ROWS: int = BLOCKED_GAP_ROWS
const LONG_GAP_CYCLE: int = BLOCKED_GAP_CYCLE

static func wrap_lane(lane: int, delta: int, lane_count: int = LANE_COUNT) -> int:
	var next_lane := (lane + delta) % lane_count
	if next_lane < 0:
		next_lane += lane_count
	return next_lane

static func lane_angle(lane: int, lane_count: int = LANE_COUNT) -> float:
	return TAU * float(lane) / float(lane_count)

static func segment_has_floor(segment: Dictionary, lane: int) -> bool:
	var floors: Array = segment.get("floors", [])
	if lane < 0 or lane >= floors.size():
		return false
	return bool(floors[lane])

static func segment_has_laser(segment: Dictionary, lane: int) -> bool:
	var lasers: Array = segment.get("lasers", [])
	if lane < 0 or lane >= lasers.size():
		return false
	return bool(lasers[lane])

static func segment_has_unstable(segment: Dictionary, lane: int) -> bool:
	var unstable: Array = segment.get("unstable", [])
	if lane < 0 or lane >= unstable.size():
		return false
	return bool(unstable[lane])

static func segment_has_mover(segment: Dictionary, lane: int) -> bool:
	var movers: Array = segment.get("movers", [])
	if lane < 0 or lane >= movers.size():
		return false
	return bool(movers[lane])

static func segment_has_jump_marker(segment: Dictionary, lane: int) -> bool:
	var jump_markers: Array = segment.get("jump_markers", [])
	if lane < 0 or lane >= jump_markers.size():
		return false
	return bool(jump_markers[lane])

static func segment_has_blocked_marker(segment: Dictionary, lane: int) -> bool:
	var blocked_markers: Array = segment.get("blocked_markers", [])
	if lane < 0 or lane >= blocked_markers.size():
		return false
	return bool(blocked_markers[lane])

static func should_crash(segment: Dictionary, lane: int, is_grounded: bool, _is_ducking: bool) -> bool:
	if is_grounded and not segment_has_floor(segment, lane):
		return true
	if is_grounded and segment_has_unstable(segment, lane):
		return true
	if segment_has_laser(segment, lane):
		return true
	if is_grounded and segment_has_mover(segment, lane):
		return true
	return false

static func speed_for_distance(distance: float) -> float:
	return 14.0 + min(distance / 230.0, 13.0)

static func make_segment(index: int, lane_count: int = LANE_COUNT, map_seed: int = 0) -> Dictionary:
	var floors: Array = []
	var lasers: Array = []
	var unstable: Array = []
	var movers: Array = []
	var jump_markers: Array = []
	var blocked_markers: Array = []
	for _i in range(lane_count):
		floors.append(true)
		lasers.append(false)
		unstable.append(false)
		movers.append(false)
		jump_markers.append(false)
		blocked_markers.append(false)

	if index >= SAFE_START_SEGMENTS:
		var jump_gap_lane: int = jumpable_gap_lane_for_segment(index, lane_count, map_seed)
		if jump_gap_lane >= 0:
			floors[jump_gap_lane] = false
		var blocked_gap_lane: int = blocked_gap_lane_for_segment(index, lane_count, map_seed)
		if blocked_gap_lane >= 0:
			floors[blocked_gap_lane] = false
		if _should_spawn_extra_gap(index, jump_gap_lane, blocked_gap_lane):
			var extra_gap_lane: int = _extra_gap_lane_for_segment(index, lane_count, map_seed)
			floors[extra_gap_lane] = false
			if index % (EXTRA_GAP_CYCLE * 2) == 0:
				floors[wrap_lane(extra_gap_lane, 2, lane_count)] = false
		var jump_warning_lane: int = jump_marker_lane_for_segment(index, lane_count, map_seed)
		if jump_warning_lane >= 0:
			jump_markers[jump_warning_lane] = true
		var blocked_warning_lane: int = blocked_marker_lane_for_segment(index, lane_count, map_seed)
		if blocked_warning_lane >= 0:
			blocked_markers[blocked_warning_lane] = true
		if _should_spawn_mover(index):
			var mover_lane := positive_mod(map_seed * 7 + index * 2 + 3, lane_count)
			if not bool(floors[mover_lane]):
				mover_lane = _first_floor_lane(floors, lane_count)
			if mover_lane >= 0:
				movers[mover_lane] = true
		if not _arrays_have_safe_lane(floors, lasers, unstable, movers, lane_count):
			var safe_lane := positive_mod(index + 1, lane_count)
			floors[safe_lane] = true
			lasers[safe_lane] = false
			unstable[safe_lane] = false
			movers[safe_lane] = false

	return {
		"index": index,
		"floors": floors,
		"lasers": lasers,
		"unstable": unstable,
		"movers": movers,
		"jump_markers": jump_markers,
		"blocked_markers": blocked_markers
	}

static func jumpable_gap_lane_for_segment(index: int, lane_count: int = LANE_COUNT, map_seed: int = 0) -> int:
	return _gap_lane_for_segment(index, JUMP_GAP_FIRST_SEGMENT, JUMPABLE_GAP_ROWS, JUMP_GAP_CYCLE, lane_count, map_seed, 1)

static func blocked_gap_lane_for_segment(index: int, lane_count: int = LANE_COUNT, map_seed: int = 0) -> int:
	return _gap_lane_for_segment(index, BLOCKED_GAP_FIRST_SEGMENT, BLOCKED_GAP_ROWS, BLOCKED_GAP_CYCLE, lane_count, map_seed, 3)

static func jump_marker_lane_for_segment(index: int, lane_count: int = LANE_COUNT, map_seed: int = 0) -> int:
	return _marker_lane_for_segment(index, JUMP_GAP_FIRST_SEGMENT, JUMP_WARNING_ROWS, JUMP_GAP_CYCLE, lane_count, map_seed, 1)

static func blocked_marker_lane_for_segment(index: int, lane_count: int = LANE_COUNT, map_seed: int = 0) -> int:
	return _marker_lane_for_segment(index, BLOCKED_GAP_FIRST_SEGMENT, BLOCKED_WARNING_ROWS, BLOCKED_GAP_CYCLE, lane_count, map_seed, 3)

static func long_gap_lane_for_segment(index: int, lane_count: int = LANE_COUNT, map_seed: int = 0) -> int:
	return blocked_gap_lane_for_segment(index, lane_count, map_seed)

static func segment_has_safe_lane(segment: Dictionary, lane_count: int = LANE_COUNT) -> bool:
	for lane in range(lane_count):
		if segment_has_floor(segment, lane) and not segment_has_laser(segment, lane) and not segment_has_unstable(segment, lane) and not segment_has_mover(segment, lane):
			return true
	return false

static func positive_mod(value: int, modulo: int) -> int:
	var result := value % modulo
	if result < 0:
		result += modulo
	return result

static func _gap_lane_for_segment(index: int, first_segment: int, row_count: int, cycle: int, lane_count: int, map_seed: int, salt: int) -> int:
	if index < first_segment:
		return -1
	var relative_index: int = index - first_segment
	var group: int = int(relative_index / cycle)
	var group_start: int = first_segment + group * cycle
	if index >= group_start and index < group_start + row_count:
		return _lane_for_group(group, lane_count, map_seed, salt)
	return -1

static func _marker_lane_for_segment(index: int, gap_first_segment: int, warning_rows: int, cycle: int, lane_count: int, map_seed: int, salt: int) -> int:
	if warning_rows <= 0:
		return -1
	var first_marker_segment: int = gap_first_segment - warning_rows
	if index < first_marker_segment:
		return -1
	var relative_index: int = index - first_marker_segment
	var group: int = int(relative_index / cycle)
	var gap_start: int = gap_first_segment + group * cycle
	var marker_start: int = gap_start - warning_rows
	if index >= marker_start and index < gap_start:
		return _lane_for_group(group, lane_count, map_seed, salt)
	return -1

static func _lane_for_group(group: int, lane_count: int, map_seed: int, salt: int) -> int:
	return positive_mod(map_seed * 17 + group * 3 + salt, lane_count)

static func _should_spawn_extra_gap(index: int, jump_gap_lane: int, blocked_gap_lane: int) -> bool:
	if index < EXTRA_GAP_FIRST_SEGMENT:
		return false
	if jump_gap_lane >= 0 or blocked_gap_lane >= 0:
		return false
	return (index - EXTRA_GAP_FIRST_SEGMENT) % EXTRA_GAP_CYCLE == 0

static func _extra_gap_lane_for_segment(index: int, lane_count: int, map_seed: int) -> int:
	return positive_mod(map_seed * 11 + index * 5 + 2, lane_count)

static func _should_spawn_mover(index: int) -> bool:
	if index < SAFE_START_SEGMENTS + 1:
		return false
	return index % 2 == 0 or index % 3 == 0 or index % 5 == 0

static func _first_floor_lane(floors: Array, lane_count: int) -> int:
	for lane in range(lane_count):
		if bool(floors[lane]):
			return lane
	return -1

static func _arrays_have_safe_lane(floors: Array, lasers: Array, unstable: Array, movers: Array, lane_count: int) -> bool:
	for lane in range(lane_count):
		if bool(floors[lane]) and not bool(lasers[lane]) and not bool(unstable[lane]) and not bool(movers[lane]):
			return true
	return false
