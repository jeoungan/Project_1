extends Node3D

const Rules := preload("res://scripts/electron_dash/electron_dash_rules.gd")

@export var lane_count: int = Rules.LANE_COUNT
@export var tunnel_radius: float = 4.0
@export var segment_depth: float = 2.2
@export var visible_segments: int = 34
@export var player_z: float = 3.0
@export var jump_velocity: float = 8.8
@export var gravity: float = 24.0
@export var lane_turn_speed: float = 14.0
@export var auto_restart_seconds: float = 1.1
@export var respawn_invincible_seconds: float = 2.0
@export var max_extra_lives: int = 2
@export var visual_grid_lanes: int = 10

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
var extra_lives: int = 0
var invincible_timer: float = 0.0
var status_message_timer: float = 0.0
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
	extra_lives = 0
	invincible_timer = 0.0
	status_message_timer = 0.0
	next_segment_index = 0
	is_alive = true
	restart_countdown = 0.0
	overlay_label.visible = false
	hint_label.visible = true
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
		_jump()
	elif event.is_action_pressed("restart"):
		reset_game()

func _process(delta: float) -> void:
	if not is_alive:
		restart_countdown -= delta
		if restart_countdown <= 0.0:
			reset_game()
		return
	var speed: float = Rules.speed_for_distance(distance)
	survival_time += delta
	distance += speed * delta
	score = int(survival_time)
	if invincible_timer > 0.0:
		invincible_timer = max(0.0, invincible_timer - delta)
	if status_message_timer > 0.0:
		status_message_timer = max(0.0, status_message_timer - delta)
	elif invincible_timer <= 0.0:
		overlay_label.visible = false
	_update_jump(delta)
	_update_player_transform(delta)
	_scroll_segments(speed, delta)
	_update_hud()

func _change_lane(delta_lane: int) -> void:
	player_lane = Rules.wrap_lane(player_lane, delta_lane, lane_count)
	target_angle = _roll_for_lane(player_lane)

func _jump() -> void:
	if jump_height <= 0.02:
		vertical_velocity = jump_velocity

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
		if not bool(segment["checked"]) and root.position.z >= player_z - segment_depth * 0.45:
			segment["checked"] = true
			var data: Dictionary = segment["data"]
			if Rules.segment_has_heart(data, player_lane):
				_collect_heart()
				var hearts: Array = data["hearts"]
				hearts[player_lane] = false
				data["hearts"] = hearts
				segment["data"] = data
				_rebuild_segment(segment)
			if invincible_timer <= 0.0 and Rules.should_crash(data, player_lane, jump_height <= 0.08, false):
				_handle_crash()
		if root.position.z > player_z + segment_depth * 4.0:
			root.position.z = farthest_z - segment_depth
			farthest_z = root.position.z
			segment["data"] = Rules.make_segment(next_segment_index, lane_count)
			segment["checked"] = false
			next_segment_index += 1
			_rebuild_segment(segment)

func _farthest_segment_z() -> float:
	var result: float = 0.0
	for segment in segments:
		var root := segment["root"] as Node3D
		result = min(result, root.position.z)
	return result

func _collect_heart() -> void:
	extra_lives = min(max_extra_lives, extra_lives + 1)
	overlay_label.text = "HEART +1"
	overlay_label.visible = true
	status_message_timer = 0.7

func _handle_crash() -> void:
	if invincible_timer > 0.0:
		return
	if extra_lives > 0:
		extra_lives -= 1
		invincible_timer = respawn_invincible_seconds
		jump_height = max(jump_height, 1.0)
		vertical_velocity = jump_velocity * 0.35
		overlay_label.text = "EXTRA LIFE"
		overlay_label.visible = true
		status_message_timer = respawn_invincible_seconds
		return
	_game_over()

func _game_over() -> void:
	is_alive = false
	best_score = max(best_score, score)
	restart_countdown = auto_restart_seconds
	overlay_label.text = "VOID\nTIME %d\nAUTO RESTART" % score
	overlay_label.visible = true

func _spawn_segment(z_position: float) -> void:
	var root := Node3D.new()
	root.name = "Segment%03d" % next_segment_index
	root.position.z = z_position
	tube_root.add_child(root)
	var data: Dictionary = Rules.make_segment(next_segment_index, lane_count)
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
			var color := Color(1.0, 0.55, 0.1, 1.0) if Rules.segment_has_unstable(data, lane) else Color(0.1, 0.9, 1.0, 1.0)
			root.add_child(_make_tile(lane, color, Rules.segment_has_unstable(data, lane)))
		if Rules.segment_has_laser(data, lane):
			root.add_child(_make_laser(lane))
		if Rules.segment_has_heart(data, lane):
			root.add_child(_make_heart(lane))

func _make_tunnel_grid() -> Node3D:
	var grid := Node3D.new()
	var color := Color(0.0, 0.65, 1.0, 1.0)
	for lane in range(visual_grid_lanes):
		var angle := TAU * float(lane) / float(visual_grid_lanes)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.035, 0.035, segment_depth * 0.94)
		mesh.material = _make_emissive_material(color, 1.15)
		var rail := MeshInstance3D.new()
		rail.mesh = mesh
		_place_at_angle(rail, angle, tunnel_radius + 0.03)
		grid.add_child(rail)
	return grid

func _make_tile(lane: int, color: Color, is_unstable: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	var panel_width: float = max(1.55, TAU * tunnel_radius / float(lane_count) * 0.48)
	mesh.size = Vector3(panel_width, 0.12, segment_depth * (0.74 if is_unstable else 0.82))
	mesh.material = _make_emissive_material(color, 1.8 if is_unstable else 1.35)
	var tile := MeshInstance3D.new()
	tile.mesh = mesh
	_place_on_tunnel(tile, lane, tunnel_radius)
	return tile

func _make_laser(lane: int) -> Node3D:
	var root := Node3D.new()
	var panel_width: float = max(1.55, TAU * tunnel_radius / float(lane_count) * 0.42)
	for z_offset in [-0.22, 0.22]:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(panel_width, 0.12, 0.12)
		mesh.material = _make_emissive_material(Color(1.0, 0.05, 0.18, 1.0), 3.0)
		var laser := MeshInstance3D.new()
		laser.mesh = mesh
		_place_on_tunnel(laser, lane, tunnel_radius - 1.05)
		laser.position.z += z_offset
		root.add_child(laser)
	return root

func _make_heart(lane: int) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.38
	mesh.material = _make_emissive_material(Color(1.0, 0.12, 0.42, 1.0), 2.4)
	var heart := MeshInstance3D.new()
	heart.mesh = mesh
	_place_on_tunnel(heart, lane, tunnel_radius - 1.18)
	return heart

func _place_on_tunnel(node: Node3D, lane: int, radius: float) -> void:
	var angle: float = _visual_lane_angle(lane)
	_place_at_angle(node, angle, radius)

func _place_at_angle(node: Node3D, angle: float, radius: float) -> void:
	var normal := Vector3(cos(angle), sin(angle), 0.0)
	var tangent := Vector3(-sin(angle), cos(angle), 0.0)
	node.transform = Transform3D(Basis(tangent, normal, Vector3(0.0, 0.0, 1.0)), normal * radius)

func _visual_lane_angle(lane: int) -> float:
	return Rules.lane_angle(lane, lane_count)

func _roll_for_lane(lane: int) -> float:
	return PI * 1.5 - _visual_lane_angle(lane)

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

func _build_player_mesh() -> void:
	for child in player_visual.get_children():
		child.free()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.24
	mesh.height = 0.82
	mesh.material = _make_emissive_material(Color(0.16, 0.55, 1.0, 1.0), 1.25)
	player_visual.mesh = mesh

	var visor_mesh := SphereMesh.new()
	visor_mesh.radius = 0.13
	visor_mesh.height = 0.16
	visor_mesh.material = _make_emissive_material(Color(1.0, 0.45, 0.06, 1.0), 1.8)
	var visor := MeshInstance3D.new()
	visor.mesh = visor_mesh
	visor.position = Vector3(0.0, 0.12, 0.24)
	visor.scale = Vector3(1.35, 0.72, 0.5)
	player_visual.add_child(visor)

	for side in [-1.0, 1.0]:
		var limb_mesh := CapsuleMesh.new()
		limb_mesh.radius = 0.055
		limb_mesh.height = 0.38
		limb_mesh.material = _make_emissive_material(Color(0.75, 0.92, 1.0, 1.0), 0.55)
		var limb := MeshInstance3D.new()
		limb.mesh = limb_mesh
		limb.position = Vector3(side * 0.24, -0.02, 0.0)
		limb.rotation.z = side * 0.38
		player_visual.add_child(limb)

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

func _update_hud() -> void:
	score_label.text = "TIME %03d   BEST %03d" % [score, best_score]
	speed_label.text = "SPEED %.1f   HEARTS %d" % [Rules.speed_for_distance(distance), extra_lives]
	hint_label.text = "A/D or Arrows   W/Up: jump   R: restart"
	hint_label.visible = survival_time < 4.0
