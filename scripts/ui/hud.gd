class_name HUD
extends CanvasLayer

var health_label: Label = null
var distance_label: Label = null
var desire_bar: ProgressBar = null
var status_label: Label = null

func _ready() -> void:
	_bind_nodes()

func _bind_nodes() -> void:
	if health_label == null:
		health_label = get_node_or_null("%HealthLabel") as Label
	if distance_label == null:
		distance_label = get_node_or_null("%DistanceLabel") as Label
	if desire_bar == null:
		desire_bar = get_node_or_null("%DesireBar") as ProgressBar
	if status_label == null:
		status_label = get_node_or_null("%StatusLabel") as Label

func set_health(value: int) -> void:
	_bind_nodes()
	if health_label:
		health_label.text = "HP %d" % value

func set_distance(value: float, target: float) -> void:
	_bind_nodes()
	if distance_label:
		distance_label.text = "%04dm / %04dm" % [int(value), int(target)]

func set_desire(value: int, max_value: int) -> void:
	_bind_nodes()
	if desire_bar:
		desire_bar.max_value = max_value
		desire_bar.value = value

func set_status(text: String) -> void:
	_bind_nodes()
	if status_label:
		status_label.text = text
