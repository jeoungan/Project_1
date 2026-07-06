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

var player_lane: int = 0
var target_angle: float = 0.0
var visual_angle: float = 0.0
var jump_height: float = 0.0
var vertical_velocity: float = 0.0
var is_alive: bool = true
var distance: float = 0.0
var score: int = 0
var next_segment_index: int = 0
var segments: Array = []

@onready var tube_root: Node3D = %TubeRoot
@onready var player_pivot: Node3D = %PlayerPivot
@onready var player_visual: MeshInstance3D = %PlayerVisual
@onready var score_label: Label = %ScoreLabel
@onready var speed_label: Label = %SpeedLabel
@onready var hint_label: Label = %HintLabel
@onready var overlay_label: Label = %OverlayLabel

func _ready() -> void:
	_build_player_mesh()
	reset_game()

func reset_game() -> void:
	for child in tube_root.get_children():
		child.queue_free()
	segments.clear()
	player_lane = 0
	target_angle = Rules.lane_angle(player_lane, lane_count)
	visual_angle = target_angle
	jump_height = 0.0
	vertical_velocity = 0.0
	distance = 0.0
	score = 0
	next_segment_index = 0
	is_alive = true
	overlay_label.visible = false
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
		return
	var speed: float = Rules.speed_for_distance(distance)
	distance += speed * delta
	score = int(distance * 10.0)
	_update_jump(delta)
	_update_player_transform(delta)
	_scroll_segments(speed, delta)
	_update_hud()

func _change_lane(delta_lane: int) -> void:
	player_lane = Rules.wrap_lane(player_lane, delta_lane, lane_count)
	target_angle = Rules.lane_angle(player_lane, lane_count)

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
	player_pivot.rotation.z = visual_angle
	player_pivot.position = Vector3(0.0, 0.0, player_z)
	player_visual.position = Vector3(tunnel_radius - 0.55 - jump_height, 0.0, 0.0)

func _scroll_segments(speed: float, delta: float) -> void:
	var farthest_z: float = _farthest_segment_z()
	for segment in segments:
		var root := segment["root"] as Node3D
		root.position.z += speed * delta
		if not bool(segment["checked"]) and root.position.z >= player_z:
			segment["checked"] = true
			if Rules.should_crash(segment["data"], player_lane, jump_height <= 0.08, Input.is_action_pressed("duck")):
				_game_over()
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

func _game_over() -> void:
	is_alive = false
	overlay_label.text = "SYSTEM FAILURE\nSCORE %d\nPRESS R TO RESTART" % score
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
		child.queue_free()
	var data: Dictionary = segment["data"]
	for lane in range(lane_count):
		if Rules.segment_has_floor(data, lane):
			root.add_child(_make_tile(lane, Color(0.1, 0.9, 1.0, 1.0)))
		if Rules.segment_has_laser(data, lane):
			root.add_child(_make_laser(lane))

func _make_tile(lane: int, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.55, 0.12, segment_depth * 0.82)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.55
	mesh.material = material
	var tile := MeshInstance3D.new()
	tile.mesh = mesh
	_place_on_tunnel(tile, lane, tunnel_radius)
	return tile

func _make_laser(lane: int) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.35, 0.18, segment_depth * 0.55)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.1, 0.25, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.05, 0.15, 1.0)
	material.emission_energy_multiplier = 2.0
	mesh.material = material
	var laser := MeshInstance3D.new()
	laser.mesh = mesh
	_place_on_tunnel(laser, lane, tunnel_radius - 0.75)
	return laser

func _place_on_tunnel(node: Node3D, lane: int, radius: float) -> void:
	var angle: float = Rules.lane_angle(lane, lane_count)
	var normal := Vector3(cos(angle), sin(angle), 0.0)
	var tangent := Vector3(-sin(angle), cos(angle), 0.0)
	node.transform = Transform3D(Basis(tangent, normal, Vector3(0.0, 0.0, 1.0)), normal * radius)

func _build_player_mesh() -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.24
	mesh.height = 0.82
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.9, 0.2, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.75, 0.1, 1.0)
	material.emission_energy_multiplier = 1.2
	mesh.material = material
	player_visual.mesh = mesh

func _update_hud() -> void:
	score_label.text = "SCORE %06d" % score
	speed_label.text = "SPEED %.1f" % Rules.speed_for_distance(distance)
	hint_label.text = "A/D or Arrows: rotate   Space: jump   S/Down: duck laser   R: restart"
