class_name RunnerPlayer
extends Area2D

signal damaged(health: int)
signal defeated
signal desire_collected(amount: int)

@export var lane_positions: PackedFloat32Array = PackedFloat32Array([-260.0, 0.0, 260.0])
@export var lane_lerp_speed: float = 16.0
@export var jump_speed: float = -760.0
@export var gravity_strength: float = 2100.0

var lane_index: int = 1
var jump_count: int = 0
var vertical_velocity: float = 0.0
var y_offset: float = 0.0
var is_ducking: bool = false
var health: int = 3

func move_lane(direction: int) -> bool:
	var next_lane: int = clamp(lane_index + direction, 0, lane_positions.size() - 1)
	if next_lane == lane_index:
		return false
	lane_index = next_lane
	return true

func try_jump() -> bool:
	if jump_count >= 2:
		return false
	jump_count += 1
	vertical_velocity = jump_speed
	is_ducking = false
	return true

func land() -> void:
	jump_count = 0
	vertical_velocity = 0.0
	y_offset = 0.0

func set_ducking(active: bool) -> void:
	if jump_count > 0 and active:
		return
	is_ducking = active

func apply_hit(damage: int) -> void:
	health = max(health - damage, 0)
	damaged.emit(health)
	if health == 0:
		defeated.emit()

func collect_desire(amount: int) -> void:
	desire_collected.emit(amount)

func get_lane_offset() -> float:
	return lane_positions[lane_index]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		move_lane(-1)
	elif event.is_action_pressed("move_right"):
		move_lane(1)
	elif event.is_action_pressed("jump"):
		try_jump()
	elif event.is_action_pressed("duck"):
		set_ducking(true)
	elif event.is_action_released("duck"):
		set_ducking(false)

func _physics_process(delta: float) -> void:
	vertical_velocity += gravity_strength * delta
	y_offset += vertical_velocity * delta
	if y_offset > 0.0:
		land()

	var target_x: float = get_lane_offset()
	position.x = lerp(position.x, target_x, min(1.0, lane_lerp_speed * delta))
	position.y = y_offset
