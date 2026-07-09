extends Node3D

const Rules := preload("res://scripts/electron_dash/electron_dash_rules.gd")
const UiFont := preload("res://assets/fonts/NanumGothic.ttf")

@export var lane_count: int = Rules.LANE_COUNT
@export var tunnel_radius: float = 4.0
@export var segment_depth: float = 3.6
@export var visible_segments: int = 32
@export var player_z: float = 3.0
@export var jump_velocity: float = 10.4
@export var gravity: float = 20.0
@export var lane_turn_speed: float = 6.8
@export var auto_restart_seconds: float = 1.1
@export var respawn_invincible_seconds: float = 2.0
@export var visual_grid_lanes: int = 10
@export var hazard_check_lead: float = 0.15
@export var jump_buffer_seconds: float = 0.14
@export var jump_ready_height: float = 0.08
@export var lane_change_grace_seconds: float = 0.22
@export var mover_phase_speed: float = 2.2
@export var swipe_min_distance: float = 52.0
@export var portrait_camera_fov: float = 66.0
@export var landscape_camera_fov: float = 76.0
@export var portrait_camera_z: float = 13.6
@export var landscape_camera_z: float = 12.0
@export var portrait_camera_y: float = 0.55
@export var death_overlay_fade_seconds: float = 0.28
@export var restart_transition_seconds: float = 0.24
@export var spawn_fade_seconds: float = 0.24

var player_lane: int = 0
var target_angle: float = 0.0
var visual_angle: float = 0.0
var jump_height: float = 0.0
var vertical_velocity: float = 0.0
var is_alive: bool = true
var distance: float = 0.0
var score: int = 0
var best_score: int = 0
var survival_time: float = 0.0
var world_time: float = 0.0
var invincible_timer: float = 0.0
var status_message_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var lane_change_grace_timer: float = 0.0
var map_seed: int = 0
var map_run_counter: int = 0
var next_segment_index: int = 0
var segments: Array = []
var restart_countdown: float = 0.0
var shadow_visual: MeshInstance3D = null
var touch_active: bool = false
var touch_start_position: Vector2 = Vector2.ZERO
var touch_drag_delta: Vector2 = Vector2.ZERO
var touch_swipe_consumed: bool = false
var death_timer: float = 0.0
var restart_transition_timer: float = 0.0
var restart_start_alpha: float = 0.0
var spawn_fade_timer: float = 0.0
var is_restart_transitioning: bool = false

@onready var tube_root: Node3D = %TubeRoot
@onready var player_pivot: Node3D = %PlayerPivot
@onready var player_visual: MeshInstance3D = %PlayerVisual
@onready var camera_3d: Camera3D = $Camera3D
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var score_label: Label = %ScoreLabel
@onready var speed_label: Label = %SpeedLabel
@onready var hint_label: Label = %HintLabel
@onready var overlay_backdrop: ColorRect = %OverlayBackdrop
@onready var overlay_label: Label = %OverlayLabel

func _ready() -> void:
	_configure_world()
	_configure_overlay()
	_build_player_mesh()
	reset_game()

func reset_game(with_intro_fade: bool = false) -> void:
	for child in tube_root.get_children():
		child.queue_free()
	segments.clear()
	player_lane = 0
	target_angle = _roll_for_lane(player_lane)
	visual_angle = target_angle
	jump_height = 0.0
	vertical_velocity = 0.0
	distance = 0.0
	survival_time = 0.0
	score = 0
	map_run_counter += 1
	map_seed = _next_map_seed()
	invincible_timer = 0.0
	status_message_timer = 0.0
	jump_buffer_timer = 0.0
	lane_change_grace_timer = 0.0
	touch_active = false
	touch_drag_delta = Vector2.ZERO
	touch_swipe_consumed = false
	death_timer = 0.0
	restart_transition_timer = 0.0
	restart_start_alpha = 0.0
	is_restart_transitioning = false
	next_segment_index = 0
	is_alive = true
	restart_countdown = 0.0
	overlay_label.visible = false
	player_visual.scale = Vector3.ONE
	hint_label.visible = false
	for i in range(visible_segments):
		_spawn_segment(-float(i) * segment_depth)
	_update_player_transform(0.0)
	_update_hud()
	if with_intro_fade:
		spawn_fade_timer = spawn_fade_seconds
		overlay_backdrop.visible = true
		_set_overlay_alpha(1.0)
	else:
		spawn_fade_timer = 0.0
		overlay_backdrop.visible = false
		_set_overlay_alpha(0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
		return
	if event is InputEventScreenDrag:
		_handle_screen_drag(event)
		return
	if event.is_action_pressed("move_left") and is_alive:
		_change_lane(-1)
	elif event.is_action_pressed("move_right") and is_alive:
		_change_lane(1)
	elif event.is_action_pressed("jump") and is_alive:
		_queue_jump()
	elif event.is_action_pressed("restart"):
		_request_restart()

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if not is_alive:
			_request_restart()
			return
		touch_active = true
		touch_swipe_consumed = false
		touch_start_position = event.position
		touch_drag_delta = Vector2.ZERO
		return
	if touch_active and is_alive and not touch_swipe_consumed:
		var release_delta: Vector2 = event.position - touch_start_position
		if touch_drag_delta.length() > release_delta.length():
			release_delta = touch_drag_delta
		_try_apply_swipe_delta(release_delta)
	touch_active = false
	touch_drag_delta = Vector2.ZERO
	touch_swipe_consumed = false

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if not is_alive or not touch_active or touch_swipe_consumed:
		return
	touch_drag_delta += event.relative
	var position_delta: Vector2 = event.position - touch_start_position
	var swipe_delta: Vector2 = position_delta
	if touch_drag_delta.length() > position_delta.length():
		swipe_delta = touch_drag_delta
	_try_apply_swipe_delta(swipe_delta)

func _try_apply_swipe_delta(delta: Vector2) -> bool:
	if delta.length() < swipe_min_distance:
		return false
	var abs_x: float = abs(delta.x)
	var abs_y: float = abs(delta.y)
	if abs_x >= swipe_min_distance and abs_x >= abs_y * 0.85:
		_change_lane(1 if delta.x > 0.0 else -1)
		touch_swipe_consumed = true
		return true
	if delta.y <= -swipe_min_distance and abs_y >= abs_x * 0.75:
		_queue_jump()
		touch_swipe_consumed = true
		return true
	return false

func _process(delta: float) -> void:
	if is_restart_transitioning:
		_update_restart_transition(delta)
		return
	if not is_alive:
		_update_game_over_visuals(delta)
		return
	var speed: float = Rules.speed_for_distance(distance)
	world_time += delta
	survival_time += delta
	distance += speed * delta
	score = int(survival_time)
	if invincible_timer > 0.0:
		invincible_timer = max(0.0, invincible_timer - delta)
	if status_message_timer > 0.0:
		status_message_timer = max(0.0, status_message_timer - delta)
	elif invincible_timer <= 0.0:
		overlay_label.visible = false
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
	if lane_change_grace_timer > 0.0:
		lane_change_grace_timer = max(0.0, lane_change_grace_timer - delta)
	_update_jump(delta)
	_try_consume_jump()
	_update_player_transform(delta)
	_animate_movers()
	_scroll_segments(speed, delta)
	_update_spawn_fade(delta)
	_update_hud()

func _change_lane(delta_lane: int) -> void:
	if is_restart_transitioning:
		return
	player_lane = Rules.wrap_lane(player_lane, delta_lane, lane_count)
	target_angle = _roll_for_lane(player_lane)
	lane_change_grace_timer = lane_change_grace_seconds

func _request_restart() -> void:
	if is_restart_transitioning:
		return
	is_restart_transitioning = true
	restart_transition_timer = 0.0
	restart_start_alpha = overlay_backdrop.modulate.a if overlay_backdrop.visible else 0.0
	overlay_backdrop.visible = true
	if overlay_label.visible:
		overlay_label.modulate.a = restart_start_alpha

func _queue_jump() -> void:
	jump_buffer_timer = jump_buffer_seconds
	_try_consume_jump()

func _try_consume_jump() -> void:
	if jump_buffer_timer > 0.0 and jump_height <= jump_ready_height:
		vertical_velocity = jump_velocity
		jump_buffer_timer = 0.0

func _update_jump(delta: float) -> void:
	vertical_velocity -= gravity * delta
	jump_height += vertical_velocity * delta
	if jump_height < 0.0:
		jump_height = 0.0
		vertical_velocity = 0.0

func _update_player_transform(delta: float) -> void:
	var blend: float = _smoothing_weight(delta, lane_turn_speed)
	visual_angle = lerp_angle(visual_angle, target_angle, blend)
	tube_root.rotation.z = visual_angle
	player_pivot.rotation.z = 0.0
	player_pivot.position = Vector3(0.0, 0.0, player_z)
	var crash_amount: float = 0.0 if is_alive else _ease_out_cubic(min(1.0, death_timer / 0.36))
	player_visual.position = Vector3(
		0.0,
		-tunnel_radius + 0.55 + jump_height + _player_bob_offset() - crash_amount * 0.18,
		crash_amount * 0.34
	)
	player_visual.rotation = Vector3(0.0, 0.0, _player_spin_angle() + death_timer * 3.8 * crash_amount)
	player_visual.scale = Vector3(1.0 + crash_amount * 0.08, 1.0 - crash_amount * 0.10, 1.0)
	player_visual.visible = invincible_timer <= 0.0 or int(Time.get_ticks_msec() / 120) % 2 == 0
	if shadow_visual != null:
		shadow_visual.position = Vector3(0.0, -tunnel_radius + 0.04, 0.0)
		shadow_visual.scale = Vector3(1.0 + jump_height * 0.18, 1.0, 1.0 + jump_height * 0.18)
		shadow_visual.visible = true
	var viewport_size := _current_viewport_size()
	var camera_blend: float = 1.0 if delta <= 0.0 else _smoothing_weight(delta, 2.5)
	camera_3d.fov = lerp(camera_3d.fov, _target_camera_fov(viewport_size, distance), camera_blend)
	camera_3d.position.z = lerp(camera_3d.position.z, _target_camera_z(viewport_size), camera_blend)
	camera_3d.position.y = lerp(camera_3d.position.y, _target_camera_y(viewport_size), camera_blend)

func _scroll_segments(speed: float, delta: float) -> void:
	var farthest_z: float = _farthest_segment_z()
	for segment in segments:
		var root := segment["root"] as Node3D
		root.position.z += speed * delta
		if not bool(segment["checked"]) and _segment_reaches_player(root.position.z):
			segment["checked"] = true
			var data: Dictionary = segment["data"]
			if invincible_timer <= 0.0:
				var is_grounded := jump_height <= 0.08
				if is_grounded and not Rules.segment_has_floor(data, player_lane):
					_handle_crash()
				elif _hazards_are_active() and Rules.should_crash(data, player_lane, is_grounded, false):
					_handle_crash()
		if root.position.z > player_z + segment_depth * 4.0:
			root.position.z = farthest_z - segment_depth
			farthest_z = root.position.z
			segment["data"] = Rules.make_segment(next_segment_index, lane_count, map_seed)
			segment["checked"] = false
			next_segment_index += 1
			_rebuild_segment(segment)

func _farthest_segment_z() -> float:
	var result: float = 0.0
	for segment in segments:
		var root := segment["root"] as Node3D
		result = min(result, root.position.z)
	return result

func _handle_crash() -> void:
	if invincible_timer > 0.0:
		return
	_game_over()

func _segment_reaches_player(segment_z: float) -> bool:
	return segment_z >= player_z - hazard_check_lead

func _hazards_are_active() -> bool:
	return lane_change_grace_timer <= 0.0

func _renders_warning_markers() -> bool:
	return false

func _current_viewport_size() -> Vector2:
	var viewport_rect := get_viewport().get_visible_rect()
	if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
		return Vector2(1280.0, 720.0)
	return viewport_rect.size

func _is_portrait_view(view_size: Vector2) -> bool:
	return view_size.y > view_size.x * 1.15

func _target_camera_fov(view_size: Vector2, current_distance: float = 0.0) -> float:
	if _is_portrait_view(view_size):
		return portrait_camera_fov + min(current_distance / 420.0, 4.0)
	return landscape_camera_fov + min(current_distance / 260.0, 7.0)

func _target_camera_z(view_size: Vector2) -> float:
	return portrait_camera_z if _is_portrait_view(view_size) else landscape_camera_z

func _target_camera_y(view_size: Vector2) -> float:
	return portrait_camera_y if _is_portrait_view(view_size) else 0.0

func _game_over() -> void:
	is_alive = false
	best_score = max(best_score, score)
	restart_countdown = auto_restart_seconds
	death_timer = 0.0
	overlay_label.text = "기록: %d초 생존\nR 또는 화면 탭으로 다시 시작" % score
	overlay_backdrop.visible = true
	overlay_label.visible = true
	_set_overlay_alpha(0.0)

func _update_game_over_visuals(delta: float) -> void:
	death_timer += delta
	world_time += delta * 0.18
	_update_player_transform(delta)
	var fade: float = _ease_out_cubic(min(1.0, death_timer / death_overlay_fade_seconds))
	_set_overlay_alpha(fade)

func _update_restart_transition(delta: float) -> void:
	restart_transition_timer += delta
	var progress: float = min(1.0, restart_transition_timer / restart_transition_seconds)
	var eased: float = _ease_in_out_cubic(progress)
	overlay_backdrop.visible = true
	overlay_backdrop.modulate.a = lerp(restart_start_alpha, 1.0, eased)
	if overlay_label.visible:
		overlay_label.modulate.a = lerp(restart_start_alpha, 0.0, eased)
	if progress >= 1.0:
		reset_game(true)

func _update_spawn_fade(delta: float) -> void:
	if spawn_fade_timer <= 0.0:
		return
	spawn_fade_timer = max(0.0, spawn_fade_timer - delta)
	var remaining: float = spawn_fade_timer / spawn_fade_seconds
	var alpha: float = _ease_in_out_cubic(remaining)
	overlay_backdrop.visible = alpha > 0.01
	overlay_label.visible = false
	_set_overlay_alpha(alpha)

func _set_overlay_alpha(alpha: float) -> void:
	overlay_backdrop.modulate.a = alpha
	overlay_label.modulate.a = alpha

func _smoothing_weight(delta: float, responsiveness: float) -> float:
	if delta <= 0.0:
		return 1.0
	return clamp(1.0 - exp(-responsiveness * delta), 0.0, 1.0)

func _ease_out_cubic(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)

func _ease_in_out_cubic(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0)
	if t < 0.5:
		return 4.0 * t * t * t
	return 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5

func _spawn_segment(z_position: float) -> void:
	var root := Node3D.new()
	root.name = "Segment%03d" % next_segment_index
	root.position.z = z_position
	tube_root.add_child(root)
	var data: Dictionary = Rules.make_segment(next_segment_index, lane_count, map_seed)
	var segment: Dictionary = {
		"root": root,
		"data": data,
		"checked": false
	}
	segments.append(segment)
	next_segment_index += 1
	_rebuild_segment(segment)

func _rebuild_segment(segment: Dictionary) -> void:
	var root := segment["root"] as Node3D
	for child in root.get_children():
		child.free()
	var data: Dictionary = segment["data"]
	root.add_child(_make_tunnel_grid())
	for lane in range(lane_count):
		if Rules.segment_has_floor(data, lane):
			var is_unstable := Rules.segment_has_unstable(data, lane)
			root.add_child(_make_tile(lane, int(data.get("index", 0)), _tile_color(is_unstable), is_unstable))
		if Rules.segment_has_laser(data, lane):
			root.add_child(_make_laser(lane))
		if Rules.segment_has_mover(data, lane):
			root.add_child(_make_moving_obstacle(lane))

func _make_tunnel_grid() -> Node3D:
	var grid := Node3D.new()
	for lane in range(visual_grid_lanes):
		var angle := TAU * float(lane) / float(visual_grid_lanes)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.045, 0.045, segment_depth * 1.12)
		mesh.material = _make_emissive_material(_edge_color(), 1.9)
		var rail := MeshInstance3D.new()
		rail.mesh = mesh
		_place_at_angle(rail, angle, tunnel_radius + 0.03)
		grid.add_child(rail)
	return grid

func _make_tile(lane: int, segment_index: int, color: Color, is_unstable: bool = false) -> Node3D:
	var tile := Node3D.new()
	tile.name = "PanelLane%d" % lane
	_place_on_tunnel(tile, lane, tunnel_radius)
	var depth: float = _tile_depth(is_unstable)
	tile.add_child(_make_local_box(Vector3(_panel_width(1.0), 0.10, depth), Vector3.ZERO, _make_emissive_material(color, 1.8 if is_unstable else 1.35)))
	_add_tile_border(tile, depth)
	_add_tile_pattern(tile, segment_index, lane, depth)
	_add_tile_starfield(tile, segment_index, lane, depth)
	return tile

func _make_local_box(size: Vector3, local_position: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var box := MeshInstance3D.new()
	box.mesh = mesh
	box.position = local_position
	return box

func _add_tile_border(tile: Node3D, depth: float) -> void:
	var width: float = _panel_width(0.96)
	var line_thickness: float = 0.05
	var line_height: float = 0.035
	var y: float = -0.075
	var material := _make_emissive_material(_tile_border_color(), 3.25)
	tile.add_child(_make_local_box(Vector3(width, line_height, line_thickness), Vector3(0.0, y, -depth * 0.46), material))
	tile.add_child(_make_local_box(Vector3(width, line_height, line_thickness), Vector3(0.0, y, depth * 0.46), material))
	tile.add_child(_make_local_box(Vector3(line_thickness, line_height, depth * 0.92), Vector3(-width * 0.5, y, 0.0), material))
	tile.add_child(_make_local_box(Vector3(line_thickness, line_height, depth * 0.92), Vector3(width * 0.5, y, 0.0), material))

func _add_tile_pattern(tile: Node3D, segment_index: int, lane: int, depth: float) -> void:
	var seed: int = Rules.positive_mod(segment_index * 31 + lane * 17, 997)
	var width: float = _panel_width(0.70)
	var y: float = -0.105
	var material := _make_emissive_material(_tile_pattern_color(), 2.3)
	var soft_material := _make_emissive_material(_tile_pattern_soft_color(), 1.35)
	var z_shift: float = float(seed % 5 - 2) * depth * 0.025
	tile.add_child(_make_local_line(width * 0.72, 0.026, Vector3(-width * 0.08, y, -depth * 0.22 + z_shift), 0.0, material))
	tile.add_child(_make_local_line(width * 0.46, 0.026, Vector3(width * 0.16, y, depth * 0.18 - z_shift), 0.0, soft_material))
	tile.add_child(_make_local_line(depth * 0.34, 0.026, Vector3(-width * 0.36, y, z_shift), PI * 0.5, soft_material))
	tile.add_child(_make_local_line(width * 0.34, 0.022, Vector3(width * 0.28, y, -depth * 0.33), -0.58, material))
	tile.add_child(_make_local_line(width * 0.30, 0.020, Vector3(-width * 0.18, y, depth * 0.34), 0.62, soft_material))
	_add_tile_pattern_rect(tile, Vector3(width * 0.22, y, -depth * 0.03), Vector2(width * 0.26, depth * 0.22), soft_material)
	_add_tile_pattern_rect(tile, Vector3(-width * 0.18, y, depth * 0.25), Vector2(width * 0.18, depth * 0.16), material)
	_add_tile_pattern_rect(tile, Vector3(width * 0.40, y, depth * 0.02), Vector2(width * 0.13, depth * 0.12), soft_material)

func _add_tile_pattern_rect(tile: Node3D, center: Vector3, size: Vector2, material: StandardMaterial3D) -> void:
	var line: float = 0.024
	tile.add_child(_make_local_box(Vector3(size.x, 0.016, line), center + Vector3(0.0, 0.0, -size.y * 0.5), material))
	tile.add_child(_make_local_box(Vector3(size.x, 0.016, line), center + Vector3(0.0, 0.0, size.y * 0.5), material))
	tile.add_child(_make_local_box(Vector3(line, 0.016, size.y), center + Vector3(-size.x * 0.5, 0.0, 0.0), material))
	tile.add_child(_make_local_box(Vector3(line, 0.016, size.y), center + Vector3(size.x * 0.5, 0.0, 0.0), material))

func _make_local_line(length: float, thickness: float, local_position: Vector3, angle: float, material: StandardMaterial3D) -> MeshInstance3D:
	var line := _make_local_box(Vector3(length, 0.018, thickness), local_position, material)
	line.rotation.y = angle
	return line

func _add_tile_starfield(tile: Node3D, segment_index: int, lane: int, depth: float) -> void:
	var width: float = _panel_width(0.82)
	var y: float = -0.125
	var seed: int = Rules.positive_mod(segment_index * 97 + lane * 53 + 19, 1009)
	for dot_index in range(12):
		var x_roll: int = Rules.positive_mod(seed * (dot_index + 3) + dot_index * 71, 1000)
		var z_roll: int = Rules.positive_mod(seed * (dot_index + 5) + dot_index * 113, 1000)
		var x: float = (float(x_roll) / 1000.0 - 0.5) * width
		var z: float = (float(z_roll) / 1000.0 - 0.5) * depth * 0.78
		var size: float = 0.024 + float((seed + dot_index * 17) % 4) * 0.008
		var material := _make_emissive_material(_star_color() if dot_index % 3 == 0 else _star_soft_color(), 3.0 if dot_index % 3 == 0 else 1.8)
		tile.add_child(_make_local_box(Vector3(size, 0.018, size), Vector3(x, y, z), material))

func _make_jump_marker(lane: int) -> MeshInstance3D:
	return _make_warning_marker(lane, _jump_marker_color(), 3.1)

func _make_blocked_marker(lane: int) -> MeshInstance3D:
	return _make_warning_marker(lane, _blocked_marker_color(), 3.3)

func _make_warning_marker(lane: int, color: Color, energy: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(_panel_width(0.86), 0.06, segment_depth * 0.22)
	mesh.material = _make_emissive_material(color, energy)
	var marker := MeshInstance3D.new()
	marker.mesh = mesh
	_place_on_tunnel(marker, lane, tunnel_radius - 0.06)
	marker.position.z += segment_depth * 0.32
	return marker

func _make_moving_obstacle(lane: int) -> Node3D:
	var root := Node3D.new()
	root.name = "MoverLane%d" % lane
	root.set_meta("lane", lane)
	_position_mover_root(root, lane)
	var outer := MeshInstance3D.new()
	outer.name = "NeonSpikeOuter"
	outer.mesh = _make_triangle_prism_mesh(_panel_width(0.42), 0.92, segment_depth * 0.32)
	outer.material_override = _make_emissive_material(_spike_edge_color(), 4.0)
	root.add_child(outer)
	var inner := MeshInstance3D.new()
	inner.name = "NeonSpikeInner"
	inner.mesh = _make_triangle_prism_mesh(_panel_width(0.30), 0.68, segment_depth * 0.25)
	inner.material_override = _make_emissive_material(_spike_fill_color(), 1.7)
	inner.position.y = -0.03
	root.add_child(inner)
	return root

func _animate_movers() -> void:
	for segment in segments:
		var segment_root := segment["root"] as Node3D
		for child in segment_root.get_children():
			if child.has_meta("lane"):
				_position_mover_root(child, int(child.get_meta("lane")))

func _position_mover_root(mover: Node3D, lane: int) -> void:
	_place_on_tunnel(mover, lane, tunnel_radius - 0.06)
	mover.position += _lane_tangent(lane) * _mover_offset(lane)

func _make_triangle_prism_mesh(width: float, height: float, depth: float) -> ArrayMesh:
	var half_width: float = width * 0.5
	var half_depth: float = depth * 0.5
	var vertices := PackedVector3Array([
		Vector3(-half_width, 0.0, -half_depth),
		Vector3(half_width, 0.0, -half_depth),
		Vector3(0.0, -height, -half_depth),
		Vector3(-half_width, 0.0, half_depth),
		Vector3(half_width, 0.0, half_depth),
		Vector3(0.0, -height, half_depth)
	])
	var indices := PackedInt32Array([
		0, 2, 1,
		3, 4, 5,
		0, 1, 4,
		0, 4, 3,
		0, 3, 5,
		0, 5, 2,
		1, 2, 5,
		1, 5, 4
	])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _make_laser(lane: int) -> Node3D:
	var root := Node3D.new()
	var panel_width: float = _panel_width(0.72)
	root.add_child(_make_laser_beam(lane, Vector3(panel_width, 0.22, 0.20), Color(1.0, 0.02, 0.08, 0.42), 2.2))
	root.add_child(_make_laser_beam(lane, Vector3(panel_width, 0.055, 0.075), Color(1.0, 0.02, 0.08, 1.0), 4.0))
	return root

func _make_laser_beam(lane: int, size: Vector3, color: Color, energy: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _make_laser_material(color, energy)
	var laser := MeshInstance3D.new()
	laser.mesh = mesh
	_place_on_tunnel(laser, lane, tunnel_radius - 1.05)
	return laser

func _place_on_tunnel(node: Node3D, lane: int, radius: float) -> void:
	var angle: float = _visual_lane_angle(lane)
	_place_at_angle(node, angle, radius)

func _lane_tangent(lane: int) -> Vector3:
	var angle: float = _visual_lane_angle(lane)
	return Vector3(-sin(angle), cos(angle), 0.0)

func _place_at_angle(node: Node3D, angle: float, radius: float) -> void:
	var normal := Vector3(cos(angle), sin(angle), 0.0)
	var tangent := Vector3(-sin(angle), cos(angle), 0.0)
	node.transform = Transform3D(Basis(tangent, normal, Vector3(0.0, 0.0, 1.0)), normal * radius)

func _visual_lane_angle(lane: int) -> float:
	return Rules.lane_angle(lane, lane_count)

func _roll_for_lane(lane: int) -> float:
	return PI * 1.5 - _visual_lane_angle(lane)

func _panel_width(scale_factor: float) -> float:
	return _lane_surface_width() * scale_factor

func _lane_surface_width() -> float:
	return TAU * tunnel_radius / float(lane_count) * 0.98

func _tile_depth(_is_unstable: bool) -> float:
	return segment_depth * 1.08

func _tile_color(is_unstable: bool) -> Color:
	return Color(0.0, 0.34, 0.88, 1.0) if is_unstable else Color(0.0, 0.22, 0.68, 1.0)

func _edge_color() -> Color:
	return Color(0.0, 0.76, 1.0, 1.0)

func _tile_border_color() -> Color:
	return Color(0.72, 0.96, 1.0, 1.0)

func _tile_pattern_color() -> Color:
	return Color(0.0, 0.58, 1.0, 1.0)

func _tile_pattern_soft_color() -> Color:
	return Color(0.0, 0.30, 0.85, 1.0)

func _star_color() -> Color:
	return Color(0.82, 0.96, 1.0, 1.0)

func _star_soft_color() -> Color:
	return Color(0.15, 0.72, 1.0, 1.0)

func _jump_marker_color() -> Color:
	return Color(0.36, 0.96, 1.0, 1.0)

func _blocked_marker_color() -> Color:
	return Color(1.0, 0.04, 0.08, 1.0)

func _spike_edge_color() -> Color:
	return Color(0.86, 0.98, 1.0, 1.0)

func _spike_fill_color() -> Color:
	return Color(0.0, 0.035, 0.12, 1.0)

func _player_color() -> Color:
	return Color(0.05, 0.85, 0.20, 1.0)

func _player_pattern_color() -> Color:
	return Color(0.68, 1.0, 0.78, 1.0)

func _mover_offset(lane: int) -> float:
	return sin(world_time * mover_phase_speed + float(lane) * 0.8) * _lane_surface_width() * 0.26

func _player_spin_angle() -> float:
	return deg_to_rad(12.0) + world_time * 2.7

func _player_bob_offset() -> float:
	if jump_height > 0.0:
		return 0.0
	return abs(sin(world_time * 10.0)) * 0.08

func _configure_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.006, 0.035, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.02, 0.12, 0.28, 1.0)
	environment.ambient_light_energy = 0.42
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.82
	environment.glow_strength = 1.25
	world_environment.environment = environment

func _configure_overlay() -> void:
	overlay_backdrop.color = Color(0.0, 0.02, 0.09, 0.76)
	overlay_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_ui_font(score_label, 18)
	_apply_ui_font(speed_label, 18)
	_apply_ui_font(hint_label, 18)
	_apply_ui_font(overlay_label, 34)
	overlay_label.add_theme_color_override("font_color", Color(0.88, 0.98, 1.0, 1.0))
	overlay_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.45, 0.9, 0.95))
	overlay_label.add_theme_constant_override("shadow_offset_x", 3)
	overlay_label.add_theme_constant_override("shadow_offset_y", 3)

func _apply_ui_font(label: Label, font_size: int) -> void:
	label.add_theme_font_override("font", UiFont)
	label.add_theme_font_size_override("font_size", font_size)

func _next_map_seed() -> int:
	var seed: int = int((Time.get_ticks_usec() + map_run_counter * 7919) % 2147483647)
	return max(1, seed)

func _build_player_mesh() -> void:
	for child in player_visual.get_children():
		child.free()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.62, 0.62, 0.62)
	mesh.material = _make_emissive_material(_player_color(), 1.65)
	player_visual.mesh = mesh
	player_visual.rotation.z = _player_spin_angle()
	_add_player_cube_pattern()

	if shadow_visual == null:
		var shadow_mesh := CylinderMesh.new()
		shadow_mesh.top_radius = 0.42
		shadow_mesh.bottom_radius = 0.42
		shadow_mesh.height = 0.018
		var shadow_material := StandardMaterial3D.new()
		shadow_material.albedo_color = Color(0.0, 0.0, 0.0, 0.45)
		shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shadow_mesh.material = shadow_material
		shadow_visual = MeshInstance3D.new()
		shadow_visual.name = "ShadowVisual"
		shadow_visual.mesh = shadow_mesh
		player_pivot.add_child(shadow_visual)

func _add_player_cube_pattern() -> void:
	var material := _make_emissive_material(_player_pattern_color(), 3.2)
	var soft_material := _make_emissive_material(Color(0.18, 1.0, 0.95, 1.0), 2.4)
	var face_z: float = -0.326
	player_visual.add_child(_make_local_box(Vector3(0.35, 0.035, 0.035), Vector3(0.0, -0.13, face_z), material))
	player_visual.add_child(_make_local_box(Vector3(0.035, 0.29, 0.035), Vector3(-0.14, 0.02, face_z), material))
	player_visual.add_child(_make_local_box(Vector3(0.20, 0.030, 0.035), Vector3(0.10, 0.16, face_z), soft_material))
	player_visual.add_child(_make_local_box(Vector3(0.030, 0.18, 0.035), Vector3(0.19, 0.03, face_z), soft_material))
	player_visual.add_child(_make_local_box(Vector3(0.16, 0.028, 0.035), Vector3(-0.02, 0.31, 0.0), material))
	player_visual.add_child(_make_local_box(Vector3(0.028, 0.16, 0.035), Vector3(0.16, 0.31, 0.0), soft_material))

func _make_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _make_laser_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _make_emissive_material(color, energy)
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _update_hud() -> void:
	score_label.text = "TIME %03d   BEST %03d" % [score, best_score]
	speed_label.text = "SPEED %.1f" % Rules.speed_for_distance(distance)
	hint_label.text = "A/D or Arrows   W/Up: jump   R: restart"
	hint_label.visible = false
