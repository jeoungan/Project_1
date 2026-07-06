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
	var packed: PackedScene = load("res://scenes/main/ElectronDashGame.tscn")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame

	if not _check(game.lane_count == 5, "game uses five panels"):
		return

	game._change_lane(1)
	game._update_player_transform(0.2)
	var player_pivot: Node3D = game.get_node("%PlayerPivot")
	var tube_root: Node3D = game.get_node("%TubeRoot")
	if not _check(abs(player_pivot.rotation.z) < 0.001, "player stays visually fixed"):
		return
	if not _check(abs(tube_root.rotation.z) > 0.01, "ground rotates under player"):
		return

	var first_angle: float = game._visual_lane_angle(0)
	var second_angle: float = game._visual_lane_angle(1)
	if not _check(is_equal_approx(first_angle, 0.0), "first panel uses canonical tube angle"):
		return
	if not _check(abs((second_angle - first_angle) - (TAU / float(game.lane_count))) < 0.001, "panels use five-way spacing"):
		return

	game._game_over()
	if not _check(not game.is_alive, "game enters fail state first"):
		return
	game._process(game.auto_restart_seconds + 0.1)
	if not _check(game.is_alive, "game auto-restarts instead of staying frozen"):
		return

	game.free()
	print("test_electron_dash_game_behavior passed")
	quit(0)
