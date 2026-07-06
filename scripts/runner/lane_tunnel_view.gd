class_name LaneTunnelView
extends Node2D

@export var lane_positions: PackedFloat32Array = PackedFloat32Array([-260.0, 0.0, 260.0])
@export var horizon_y: float = 130.0
@export var floor_y: float = 575.0
@export var scroll_speed: float = 260.0

var scroll_offset: float = 0.0
var twist: float = 0.0
var burst_strength: float = 0.0

func set_twist_from_lane(lane_index: int) -> void:
	twist = float(lane_index - 1) * 0.08

func set_burst(active: bool) -> void:
	burst_strength = 1.0 if active else 0.0
	queue_redraw()

func _process(delta: float) -> void:
	scroll_offset = fmod(scroll_offset + scroll_speed * delta, 120.0)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2(-700, -80), Vector2(1400, 800)), Color(0.04, 0.05, 0.1))
	var glow := Color(0.18 + burst_strength * 0.35, 0.45, 0.75 + burst_strength * 0.2, 0.4)
	for i in range(12):
		var t := float(i) / 11.0
		var y: float = lerp(horizon_y, floor_y, t)
		var width: float = lerp(160.0, 1150.0, t)
		var x_shift: float = sin(t * 4.0 + scroll_offset * 0.02) * 24.0 + twist * 420.0 * t
		draw_line(Vector2(-width * 0.5 + x_shift, y), Vector2(width * 0.5 + x_shift, y), glow, 3.0)
	for lane_x in lane_positions:
		draw_line(Vector2(lane_x * 0.2, horizon_y), Vector2(lane_x, floor_y), Color(0.45, 0.85, 1.0, 0.55), 4.0)
