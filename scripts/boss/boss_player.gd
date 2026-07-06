class_name BossPlayer
extends CharacterBody2D

signal attacked
signal damaged(health: int)
signal defeated

@export var speed: float = 430.0
@export var jump_velocity: float = -760.0
@export var gravity_strength: float = 2100.0
@export var dash_speed: float = 850.0
@export var dash_seconds: float = 0.14

var health: int = 3
var jump_count: int = 0
var dash_time_left: float = 0.0
var facing: float = 1.0

func _physics_process(delta: float) -> void:
	var axis := Input.get_axis("move_left", "move_right")
	if axis != 0.0:
		facing = sign(axis)
	velocity.x = axis * speed
	if dash_time_left > 0.0:
		dash_time_left -= delta
		velocity.x = facing * dash_speed
	if not is_on_floor():
		velocity.y += gravity_strength * delta
	else:
		jump_count = 0
	if Input.is_action_just_pressed("jump") and jump_count < 2:
		velocity.y = jump_velocity
		jump_count += 1
	if Input.is_action_just_pressed("dash"):
		dash_time_left = dash_seconds
	if Input.is_action_just_pressed("attack"):
		attacked.emit()
	move_and_slide()

func apply_hit(damage: int) -> void:
	health = max(health - damage, 0)
	damaged.emit(health)
	if health == 0:
		defeated.emit()
