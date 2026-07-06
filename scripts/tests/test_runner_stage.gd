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
	var packed: PackedScene = load("res://scenes/runner/RunnerStage.tscn")
	var stage = packed.instantiate()
	root.add_child(stage)
	stage.target_distance = 100.0
	stage.base_speed = 50.0

	var completed := [false]
	stage.stage_completed.connect(func() -> void:
		completed[0] = true
	)

	stage.advance_distance(1.0)
	if not _check(stage.distance == 50.0, "distance advances by speed"):
		return
	stage.advance_distance(1.0)
	if not _check(completed[0], "stage completes at target distance"):
		return
	if not _check(stage.get_node("%RunnerPlayer") != null, "runner player exists"):
		return
	if not _check(stage.get_node("%HUD") != null, "HUD exists"):
		return
	var player = stage.get_node("%RunnerPlayer")
	var obstacle = load("res://scripts/runner/obstacle.gd").new()
	obstacle.height_tag = "high"
	player.set_ducking(true)
	if not _check(stage._player_avoids_obstacle(obstacle), "ducking avoids high obstacle"):
		return
	player.set_ducking(false)
	if not _check(not stage._player_avoids_obstacle(obstacle), "standing hits high obstacle"):
		return
	obstacle.height_tag = "ground"
	player.try_jump()
	if not _check(stage._player_avoids_obstacle(obstacle), "jumping avoids ground obstacle"):
		return
	obstacle.free()
	stage.free()

	print("test_runner_stage passed")
	quit(0)
