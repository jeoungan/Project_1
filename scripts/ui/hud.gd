class_name HUD
extends CanvasLayer

@onready var health_label: Label = %HealthLabel
@onready var distance_label: Label = %DistanceLabel
@onready var desire_bar: ProgressBar = %DesireBar
@onready var status_label: Label = %StatusLabel

func set_health(value: int) -> void:
	health_label.text = "HP %d" % value

func set_distance(value: float, target: float) -> void:
	distance_label.text = "%04dm / %04dm" % [int(value), int(target)]

func set_desire(value: int, max_value: int) -> void:
	desire_bar.max_value = max_value
	desire_bar.value = value

func set_status(text: String) -> void:
	status_label.text = text
