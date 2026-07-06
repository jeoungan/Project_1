class_name BossArena
extends Node2D

signal boss_defeated
signal player_defeated

const PROJECTILE_SCENE := preload("res://scenes/boss/BossProjectile.tscn")

@onready var player: Node = %BossPlayer
@onready var boss: Node = %HomeroomBoss
@onready var projectile_root: Node2D = %ProjectileRoot
@onready var status_label: Label = %StatusLabel
@onready var meter: Node = %DesireMeter

func _ready() -> void:
	player.attacked.connect(_on_player_attacked)
	player.defeated.connect(func() -> void:
		player_defeated.emit()
	)
	boss.defeated.connect(func() -> void:
		status_label.text = "교문이 열린다"
		boss_defeated.emit()
	)
	boss.pattern_requested.connect(_spawn_pattern)
	meter.add_value(meter.max_value)
	var timer := Timer.new()
	timer.wait_time = boss.pattern_seconds
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		boss.request_next_pattern()
	)
	add_child(timer)

func _on_player_attacked() -> void:
	if player.position.distance_to(boss.position) < 190.0:
		if meter.consume_special():
			boss.take_damage(40)
			status_label.text = "귀가 본능 폭발"
		else:
			boss.take_damage(10)
			status_label.text = "귀가 본능 공격"

func _spawn_pattern(pattern_name: String) -> void:
	status_label.text = pattern_name
	if pattern_name == "chalk":
		_spawn_projectile(Vector2(1040, 360), Vector2(-520, 0))
	elif pattern_name == "rollbook":
		_spawn_projectile(Vector2(900, 160), Vector2(-120, 420))
	elif pattern_name == "exam_burst":
		_spawn_projectile(Vector2(1040, 280), Vector2(-480, 120))
		_spawn_projectile(Vector2(1040, 420), Vector2(-480, -80))
	elif pattern_name == "lecture_wave":
		_spawn_projectile(Vector2(1040, 530), Vector2(-360, 0))

func _spawn_projectile(start_position: Vector2, projectile_velocity: Vector2) -> void:
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.position = start_position
	projectile.velocity = projectile_velocity
	projectile_root.add_child(projectile)
