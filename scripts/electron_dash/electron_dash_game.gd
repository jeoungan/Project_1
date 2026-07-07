extends Node3D

const Rules := preload("res://scripts/electron_dash/electron_dash_rules.gd")

@export var lane_count: int = Rules.LANE_COUNT
@export var tunnel_radius: float = 4.0
@export var segment_depth: float = 3.6
@export var visible_segments: int = 32
@export var player_z: float = 3.0
@export var jump_velocity: float = 10.4
@export var gravity: float = 20.0
@export var lane_turn_speed: float = 8.0
@export var auto_restart_seconds: float = 1.1
@export var respawn_invincible_seconds: float = 2.0
@export var visual_grid_lanes: int = 10
@export var hazard_check_lead: float = 0.15
@export var jump_buffer_seconds: float = 0.14
@export var jump_ready_height: float = 0.08
@export var lane_change_grace_seconds: float = 0.22
@export var mover_phase_speed: float = 2.2

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

@onready var tube_root: Node3D = %TubeRoot
@onready var player_pivot: Node3D = %PlayerPivot
@onready var player_visual: MeshInstance3D = %PlayerVisual
@onready var camera_3d: Camera3D = $Camera3D
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var score_label: Label = %ScoreLabel
@onready var speed_label: Label = %SpeedLabel
@onready var hint_label: Label = %HintLabel
@onready var overlay_label: Label = %OverlayLabel

func _ready() -> void:
	_configure_world()
	_build_player_mesh()
	reset_game()

func reset_game() -> void:
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
	next_segment_index = 0
	is_alive = true
	restart_countdown = 0.0
	overlay_label.visible = false
	hint_label.visible = false
	for i in range(visible_segments):
		_spawn_segment(-float(i) * segment_depth)
	_update_player_transform(0.0)
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left") and is_alive:
		_change_lane(-1)
	elif event.is_action_pressed("move_right") and is_alive:
		_change_lane(1)
	elif event.is_action_pressed("jump") and is_alive:
		_queue_jump()
	elif event.is_action_pressed("restart"):
		reset_game()

func _process(delta: float) -> void:
	if not is_alive:
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
	_update_hud()

func _change_lane(delta_lane: int) -> void:
	player_lane = Rules.wrap_lane(player_lane, delta_lane, lane_count)
	target_angle = _roll_for_lane(player_lane)
	lane_change_grace_timer = lane_change_grace_seconds

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
	var blend: float = min(1.0, lane_turn_speed * delta)
	visual_angle = lerp_angle(visual_angle, target_angle, blend)
	tube_root.rotation.z = visual_angle
	player_pivot.rotation.z = 0.0
	player_pivot.position = Vector3(0.0, 0.0, player_z)
	player_visual.position = Vector3(0.0, -tunnel_radius + 0.55 + jump_height, 0.0)
	player_visual.visible = invincible_timer <= 0.0 or int(Time.get_ticks_msec() / 120) % 2 == 0
	if shadow_visual != null:
		shadow_visual.position = Vector3(0.0, -tunnel_radius + 0.04, 0.0)
		shadow_visual.scale = Vector3(1.0 + jump_height * 0.18, 1.0, 1.0 + jump_height * 0.18)
		shadow_visual.visible = true
	camera_3d.fov = lerp(camera_3d.fov, 76.0 + min(distance / 260.0, 7.0), min(1.0, delta * 2.5))

func _scroll_segments(speed: float, delta: float) -> void:
	var farthest_z: float = _farthest_segment_z()
	for segment in segments:
		var root := segment["root"] as Node3D
		root.position.z += speed * delta
		if not bool(segment["checked"]) and _segment_reaches_player(root.position.z):
			segment["checked"] = true
			var data: Dictionary = segment["data"]
			if _hazards_are_active() and invincible_timer <= 0.0 and Rules.should_crash(data, player_lane, jump_height <= 0.08, false):
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

func _game_over() -> void:
	is_alive = false
	best_score = max(best_score, score)
	restart_countdown = auto_restart_seconds
	overlay_label.text = "VOID\nTIME %d\nPRESS R TO RESTART" % score
	overlay_label.visible = true

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
			root.add_child(_make_tile(lane, _tile_color(is_unstable), is_unstable))
			if Rules.segment_has_jump_marker(data, lane):
				root.add_child(_make_jump_marker(lane))
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
		mesh.material = _make_emissive_material(_edge_color(), 1.45)
		var rail := MeshInstance3D.new()
		rail.mesh = mesh
		_place_at_angle(rail, angle, tunnel_radius + 0.03)
		grid.add_child(rail)
	return grid

func _make_tile(lane: int, color: Color, is_unstable: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(_panel_width(1.0), 0.10, _tile_depth(is_unstable))
	mesh.material = _make_emissive_material(color, 1.8 if is_unstable else 1.35)
	var tile := MeshInstance3D.new()
	tile.mesh = mesh
	_place_on_tunnel(tile, lane, tunnel_radius)
	return tile

func _make_jump_marker(lane: int) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(_panel_width(0.86), 0.06, segment_depth * 0.22)
	mesh.material = _make_emissive_material(_jump_marker_color(), 3.1)
	var marker := MeshInstance3D.new()
	marker.mesh = mesh
	_place_on_tunnel(marker, lane, tunnel_radius - 0.06)
	marker.position.z += segment_depth * 0.32
	return marker

func _make_moving_obstacle(lane: int) -> Node3D:
	var root := Node3D.new()
	root.name = "MoverLane%d" % lane
	root.set_meta("lane", lane)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(_panel_width(0.34), 0.32, segment_depth * 0.26)
	mesh.material = _make_emissive_material(Color(1.0, 0.1, 0.12, 1.0), 2.7)
	var mover := MeshInstance3D.new()
	mover.mesh = mesh
	_position_mover_mesh(mover, lane)
	root.add_child(mover)
	return root

func _animate_movers() -> void:
	for segment in segments:
		var segment_root := segment["root"] as Node3D
		for child in segment_root.get_children():
			if child.has_meta("lane") and child.get_child_count() > 0:
				var mover := child.get_child(0) as MeshInstance3D
				if mover != null:
					_position_mover_mesh(mover, int(child.get_meta("lane")))

func _position_mover_mesh(mover: MeshInstance3D, lane: int) -> void:
	_place_on_tunnel(mover, lane, tunnel_radius - 0.28)
	mover.position += _lane_tangent(lane) * _mover_offset(lane)

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
	return Color(0.035, 0.10, 0.24, 1.0) if is_unstable else Color(0.012, 0.045, 0.14, 1.0)

func _edge_color() -> Color:
	return Color(0.0, 0.82, 1.0, 1.0)

func _jump_marker_color() -> Color:
	return Color(0.1, 1.0, 0.95, 1.0)

func _mover_offset(lane: int) -> float:
	return sin(world_time * mover_phase_speed + float(lane) * 0.8) * _lane_surface_width() * 0.26

func _configure_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.005, 0.006, 0.018, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.05, 0.08, 0.14, 1.0)
	environment.ambient_light_energy = 0.35
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.65
	environment.glow_strength = 1.0
	world_environment.environment = environment

func _next_map_seed() -> int:
	var seed: int = int((Time.get_ticks_usec() + map_run_counter * 7919) % 2147483647)
	return max(1, seed)

func _build_player_mesh() -> void:
	for child in player_visual.get_children():
		child.free()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.62, 0.62, 0.62)
	mesh.material = _make_emissive_material(Color(0.16, 0.55, 1.0, 1.0), 1.25)
	player_visual.mesh = mesh
	player_visual.rotation.z = deg_to_rad(12.0)

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

func _make_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
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
