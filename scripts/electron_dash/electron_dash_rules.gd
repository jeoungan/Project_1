class_name ElectronDashRules
extends RefCounted

const LANE_COUNT: int = 5
const SAFE_START_SEGMENTS: int = 6

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

static func make_segment(index: int, lane_count: int = LANE_COUNT) -> Dictionary:
	var floors: Array = []
	var lasers: Array = []
	var unstable: Array = []
	for _i in range(lane_count):
		floors.append(true)
		lasers.append(false)
		unstable.append(false)

	if index >= SAFE_START_SEGMENTS:
		if index % 5 == 0:
			var jump_index: int = int(index / 5)
			var gap_lane := positive_mod(jump_index * 2 + 1, lane_count)
			floors[gap_lane] = false
			if index % 10 == 0:
				floors[wrap_lane(gap_lane, 1, lane_count)] = false
		if index % 7 == 0:
			lasers[positive_mod(index * 3 + 1, lane_count)] = true
		if index % 13 == 0:
			lasers[positive_mod(index * 3 + 5, lane_count)] = true
		if index % 9 == 0:
			var unstable_lane := positive_mod(index * 4 + 1, lane_count)
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
