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

static func should_crash(segment: Dictionary, lane: int, is_grounded: bool, is_ducking: bool) -> bool:
	if is_grounded and not segment_has_floor(segment, lane):
		return true
	if segment_has_laser(segment, lane) and not is_ducking:
		return true
	return false

static func speed_for_distance(distance: float) -> float:
	return 18.0 + min(distance / 220.0, 18.0)

static func make_segment(index: int, lane_count: int = LANE_COUNT) -> Dictionary:
	var floors: Array = []
	var lasers: Array = []
	for _i in range(lane_count):
		floors.append(true)
		lasers.append(false)

	if index >= SAFE_START_SEGMENTS:
		var gap_lane := positive_mod(index * 2 + 2, lane_count)
		floors[gap_lane] = false
		if index % 4 == 0:
			floors[wrap_lane(gap_lane, 1, lane_count)] = false
		if index % 5 == 0:
			lasers[positive_mod(index * 3 + 1, lane_count)] = true
		if index % 9 == 0:
			lasers[positive_mod(index * 3 + 5, lane_count)] = true

	return {
		"index": index,
		"floors": floors,
		"lasers": lasers
	}

static func positive_mod(value: int, modulo: int) -> int:
	var result := value % modulo
	if result < 0:
		result += modulo
	return result
