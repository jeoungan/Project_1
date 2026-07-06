class_name RunnerStage
extends Node2D

signal stage_completed
signal player_defeated

const OBSTACLE_SCENE := preload("res://scenes/runner/Obstacle.tscn")

@export var target_distance: float = 1200.0
@export var base_speed: float = 260.0
@export var burst_speed_bonus: float = 120.0

var distance: float = 0.0
var is_running: bool = true

var playfield: Node2D = null
var tunnel: Node = null
var player: Node = null
var obstacle_root: Node2D = null
var spawner: Node = null
var meter: Node = null
var hud: Node = null

func _ready() -> void:
	_bind_nodes()
	if spawner:
		spawner.spawn_requested.connect(_spawn_obstacle)
	if player:
		player.damaged.connect(func(health: int) -> void:
			if hud:
				hud.set_health(health)
		)
		player.defeated.connect(func() -> void:
			is_running = false
			player_defeated.emit()
		)
		player.desire_collected.connect(func(amount: int) -> void:
			if meter:
				meter.add_value(amount)
		)
		player.area_entered.connect(_on_player_area_entered)
	if meter:
		meter.changed.connect(func(value: int, max_value: int) -> void:
			if hud:
				hud.set_desire(value, max_value)
		)
		meter.burst_started.connect(func() -> void:
			if hud:
				hud.set_status("폭주 모드")
			if tunnel and tunnel.has_method("set_burst"):
				tunnel.set_burst(true)
		)
		meter.burst_ended.connect(func() -> void:
			if hud:
				hud.set_status("")
			if tunnel and tunnel.has_method("set_burst"):
				tunnel.set_burst(false)
		)
	if hud and player and meter:
		hud.set_health(player.health)
		hud.set_distance(distance, target_distance)
		hud.set_desire(meter.value, meter.max_value)

func _bind_nodes() -> void:
	if playfield == null:
		playfield = get_node_or_null("%Playfield") as Node2D
	if tunnel == null:
		tunnel = get_node_or_null("%LaneTunnelView")
	if player == null:
		player = get_node_or_null("%RunnerPlayer")
	if obstacle_root == null:
		obstacle_root = get_node_or_null("%ObstacleRoot") as Node2D
	if spawner == null:
		spawner = get_node_or_null("%ObstacleSpawner")
	if meter == null:
		meter = get_node_or_null("%DesireMeter")
	if hud == null:
		hud = get_node_or_null("%HUD")

func advance_distance(delta: float) -> void:
	_bind_nodes()
	if not is_running:
		return
	var speed: float = base_speed
	if meter and meter.is_bursting:
		speed += burst_speed_bonus
	distance = min(distance + speed * delta, target_distance)
	if hud:
		hud.set_distance(distance, target_distance)
	if spawner:
		spawner.poll(distance)
	if distance >= target_distance:
		is_running = false
		stage_completed.emit()

func _process(delta: float) -> void:
	advance_distance(delta)
	if tunnel and player and tunnel.has_method("set_twist_from_lane"):
		tunnel.set_twist_from_lane(player.lane_index)

func _spawn_obstacle(definition: Dictionary) -> void:
	_bind_nodes()
	var obstacle = OBSTACLE_SCENE.instantiate()
	var lane: int = int(definition.get("lane", 1))
	var lane_x: float = player.lane_positions[lane]
	obstacle.configure(definition, lane_x, -40.0)
	if obstacle_root:
		obstacle_root.add_child(obstacle)

func _on_player_area_entered(area: Area2D) -> void:
	if area.has_method("configure"):
		var obstacle = area
		if obstacle.is_collectible:
			player.collect_desire(obstacle.desire_value)
			obstacle.queue_free()
			return
		if _player_avoids_obstacle(obstacle):
			obstacle.queue_free()
			return
		if meter.is_bursting and obstacle.kind in ["desk", "falling_tile"]:
			obstacle.queue_free()
			return
		player.apply_hit(obstacle.damage)
		obstacle.queue_free()

func _player_avoids_obstacle(obstacle: Node) -> bool:
	if player == null:
		_bind_nodes()
	if player == null:
		return false
	var height_tag := str(obstacle.get("height_tag"))
	match height_tag:
		"ground":
			return player.has_method("is_airborne") and player.is_airborne()
		"low":
			return bool(player.get("is_ducking"))
		"high":
			return bool(player.get("is_ducking"))
		"item":
			return false
		_:
			return false
