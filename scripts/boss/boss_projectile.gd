class_name BossProjectile
extends Area2D

@export var velocity: Vector2 = Vector2(-420.0, 0.0)
@export var damage: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	position += velocity * delta
	if position.x < -120.0 or position.x > 1400.0 or position.y < -120.0 or position.y > 840.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("apply_hit"):
		body.apply_hit(damage)
		queue_free()
