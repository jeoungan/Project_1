class_name ObstacleSpawner
extends Node

signal spawn_requested(definition: Dictionary)

var patterns: Array = [
	{"distance": 80.0, "kind": "desk", "lane": 1, "height": "ground"},
	{"distance": 180.0, "kind": "shockwave", "lane": 1, "height": "low"},
	{"distance": 300.0, "kind": "falling_tile", "lane": 0, "height": "ground"},
	{"distance": 430.0, "kind": "paper_laser", "lane": 2, "height": "high"},
	{"distance": 560.0, "kind": "chalk", "lane": 0, "height": "mid"},
	{"distance": 680.0, "kind": "key", "lane": 2, "height": "item"},
	{"distance": 820.0, "kind": "desk", "lane": 0, "height": "ground"},
	{"distance": 940.0, "kind": "shockwave", "lane": 2, "height": "low"},
	{"distance": 1060.0, "kind": "paper_laser", "lane": 1, "height": "high"}
]

var next_index: int = 0

func reset() -> void:
	next_index = 0

func poll(distance: float) -> void:
	while next_index < patterns.size() and distance >= float(patterns[next_index]["distance"]):
		spawn_requested.emit(patterns[next_index])
		next_index += 1
