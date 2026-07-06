class_name RunnerObstacle
extends Area2D

@export var kind: String = "desk"
@export var lane: int = 1
@export var height_tag: String = "ground"
@export var speed: float = 420.0
@export var damage: int = 1
@export var desire_value: int = 20

var is_collectible: bool = false

func configure(definition: Dictionary, lane_x: float, start_y: float) -> void:
	kind = str(definition.get("kind", "desk"))
	lane = int(definition.get("lane", 1))
	height_tag = str(definition.get("height", "ground"))
	is_collectible = kind == "key"
	desire_value = int(definition.get("desire", desire_value))
	position = Vector2(lane_x, start_y)
	_apply_visual()

func _apply_visual() -> void:
	var body := get_node_or_null("Body")
	if body is ColorRect:
		body.color = Color(1.0, 0.85, 0.25) if is_collectible else Color(1.0, 0.25, 0.25)
		body.size = _size_for_kind()
		body.position = Vector2(-body.size.x * 0.5, -body.size.y)

func _size_for_kind() -> Vector2:
	if kind == "paper_laser":
		return Vector2(190.0, 28.0)
	if kind == "shockwave":
		return Vector2(210.0, 40.0)
	if kind == "chalk":
		return Vector2(52.0, 52.0)
	if kind == "key":
		return Vector2(46.0, 46.0)
	return Vector2(76.0, 76.0)

func _process(delta: float) -> void:
	position.y += speed * delta
	if position.y > 780.0:
		queue_free()
