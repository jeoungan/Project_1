class_name CutscenePlayer
extends Control

signal completed

@export var lines: PackedStringArray = PackedStringArray()

var index: int = 0
var title_label: Label = null
var body_label: Label = null

func _ready() -> void:
	_bind_nodes()
	show_line()

func _bind_nodes() -> void:
	if title_label == null:
		title_label = get_node_or_null("%TitleLabel") as Label
	if body_label == null:
		body_label = get_node_or_null("%BodyLabel") as Label

func configure(title: String, new_lines: PackedStringArray) -> void:
	lines = new_lines
	index = 0
	_bind_nodes()
	if title_label:
		title_label.text = title
	show_line()

func show_line() -> void:
	_bind_nodes()
	if index >= lines.size():
		completed.emit()
		return
	if body_label:
		body_label.text = lines[index]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") or event.is_action_pressed("attack"):
		index += 1
		show_line()
