extends SceneTree

func _fail(message: String) -> void:
	printerr(message)
	quit(1)

func _check(condition: bool, message: String) -> bool:
	if not condition:
		_fail(message)
		return false
	return true

func _initialize() -> void:
	var spawner = load("res://scripts/runner/obstacle_spawner.gd").new()
	root.add_child(spawner)
	spawner.patterns = [
		{"distance": 10.0, "kind": "desk", "lane": 1, "height": "ground"},
		{"distance": 20.0, "kind": "paper_laser", "lane": 0, "height": "high"}
	]

	var spawned := []
	spawner.spawn_requested.connect(func(definition: Dictionary) -> void:
		spawned.append(definition)
	)

	spawner.poll(9.0)
	if not _check(spawned.size() == 0, "no spawn before first distance"):
		return
	spawner.poll(10.0)
	if not _check(spawned.size() == 1, "first spawn at threshold"):
		return
	if not _check(spawned[0]["kind"] == "desk", "first spawn kind"):
		return
	spawner.poll(25.0)
	if not _check(spawned.size() == 2, "second spawn after threshold"):
		return

	print("test_obstacle_spawner passed")
	quit(0)
