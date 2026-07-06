class_name DesireMeter
extends Node

signal changed(value: int, max_value: int)
signal burst_started
signal burst_ended

@export var max_value: int = 100
@export var burst_seconds: float = 4.0

var value: int = 0
var is_bursting: bool = false
var burst_time_left: float = 0.0

func add_value(amount: int) -> void:
	if amount <= 0:
		return
	value = clamp(value + amount, 0, max_value)
	changed.emit(value, max_value)
	if value >= max_value and not is_bursting:
		start_burst()

func start_burst() -> void:
	is_bursting = true
	burst_time_left = burst_seconds
	burst_started.emit()

func consume_special() -> bool:
	if value < max_value and not is_bursting:
		return false
	value = 0
	changed.emit(value, max_value)
	if is_bursting:
		is_bursting = false
		burst_time_left = 0.0
		burst_ended.emit()
	return true

func reset_to_half() -> void:
	value = int(max_value * 0.5)
	is_bursting = false
	burst_time_left = 0.0
	changed.emit(value, max_value)

func _process(delta: float) -> void:
	if not is_bursting:
		return
	burst_time_left -= delta
	if burst_time_left <= 0.0:
		is_bursting = false
		burst_time_left = 0.0
		burst_ended.emit()
