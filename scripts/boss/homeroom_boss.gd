class_name HomeroomBoss
extends Node2D

signal defeated
signal pattern_requested(pattern_name: String)

@export var max_health: int = 100
@export var pattern_seconds: float = 1.6

var health: int = 100
var pattern_index: int = 0
var is_defeated: bool = false
var patterns: PackedStringArray = PackedStringArray(["chalk", "rollbook", "exam_burst", "lecture_wave"])

func _ready() -> void:
	health = max_health

func take_damage(amount: int) -> void:
	if is_defeated:
		return
	health = max(health - amount, 0)
	if health == 0:
		is_defeated = true
		defeated.emit()

func request_next_pattern() -> String:
	if is_defeated:
		return ""
	var pattern := patterns[pattern_index % patterns.size()]
	pattern_index += 1
	pattern_requested.emit(pattern)
	return pattern
