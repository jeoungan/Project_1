class_name ElectronDashRules
extends RefCounted

const LANE_COUNT: int = 5
const SAFE_START_SEGMENTS: int = 6
const LONG_GAP_FIRST_SEGMENT: int = SAFE_START_SEGMENTS + 4
const LONG_GAP_ROWS: int = 7
const LONG_GAP_CYCLE: int = 14

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

static func should_crash(segment: Dictionary, lane: int, is_grounded: bool, _is_ducking: bool) -> bool:
	if is_grounded and not segment_has_floor(segment, lane):
		return true
	if is_grounded and segment_has_unstable(segment, lane):
		return true
	if segment_has_laser(segment, lane):
		return true
	return false

static func speed_for_distance(distance: float) -> float:
	return 12.0 + min(distance / 320.0, 10.0)

static func make_segment(index: int, lane_count: int = LANE_COUNT, map_seed: int = 0) -> Dictionary:
	var floors: Array = []
	var lasers: Array = []
	var unstable: Array = []
	for _i in range(lane_count):
		floors.append(true)
		lasers.append(false)
		unstable.append(false)

	if index >= SAFE_START_SEGMENTS:
		var gap_lane: int = long_gap_lane_for_segment(index, lane_count, map_seed)
		if gap_lane >= 0:
			floors[gap_lane] = false
			if index % (LONG_GAP_CYCLE * 2) == 0:
				floors[wrap_lane(gap_lane, 1, lane_count)] = false
		if index % 9 == 0 and gap_lane < 0:
			var unstable_lane := positive_mod(map_seed * 11 + index * 4 + 1, lane_count)
			if bool(floors[unstable_lane]) and not bool(lasers[unstable_lane]):
				unstable[unstable_lane] = true
		if not _arrays_have_safe_lane(floors, lasers, unstable, lane_count):
			var safe_lane := positive_mod(index + 1, lane_count)
			floors[safe_lane] = true
			lasers[safe_lane] = false
			unstable[safe_lane] = false

	return {
		"index": index,
		"floors": floors,
		"lasers": lasers,
		"unstable": unstable
	}

static func long_gap_lane_for_segment(index: int, lane_count: int = LANE_COUNT, map_seed: int = 0) -> int:
	if index < LONG_GAP_FIRST_SEGMENT:
		return -1
	var relative_index: int = index - LONG_GAP_FIRST_SEGMENT
	var group: int = int(relative_index / LONG_GAP_CYCLE)
	var group_start: int = LONG_GAP_FIRST_SEGMENT + group * LONG_GAP_CYCLE
	if index >= group_start and index < group_start + LONG_GAP_ROWS:
		return positive_mod(map_seed * 17 + group * 3 + 1, lane_count)
	return -1

static func segment_has_safe_lane(segment: Dictionary, lane_count: int = LANE_COUNT) -> bool:
	for lane in range(lane_count):
		if segment_has_floor(segment, lane) and not segment_has_laser(segment, lane) and not segment_has_unstable(segment, lane):
			return true
	return false

static func positive_mod(value: int, modulo: int) -> int:
	var result := value % modulo
	if result < 0:
		result += modulo
	return result

static func _arrays_have_safe_lane(floors: Array, lasers: Array, unstable: Array, lane_count: int) -> bool:
	for lane in range(lane_count):
		if bool(floors[lane]) and not bool(lasers[lane]) and not bool(unstable[lane]):
			return true
	return false
