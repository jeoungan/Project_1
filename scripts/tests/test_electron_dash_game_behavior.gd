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
	if not _check(game.segment_depth >= 3.2, "rows are spaced far enough to read gaps"):
		return
	if not _check(game._tile_depth(false) >= game.segment_depth * 0.92, "ordinary road tiles connect into a continuous path"):
		return
	if not _check(game.lane_turn_speed <= 9.0, "lane rotation is eased instead of snapping"):
		return
	var hint_label: Label = game.get_node("%HintLabel")
	if not _check(not hint_label.visible, "bottom key hint stays hidden"):
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

	game.reset_game()
	game.invincible_timer = 2.0
	game._process(1.25)
	if not _check(game.score == 1, "score counts survival seconds"):
		return

	game.reset_game()
	game._collect_heart()
	if not _check(game.extra_lives == 1, "heart pickup grants an extra life"):
		return
	var overlay_label: Label = game.get_node("%OverlayLabel")
	if not _check(not overlay_label.visible, "heart pickup does not show center text"):
		return
	game._handle_crash()
	if not _check(game.is_alive, "extra life respawns instead of ending the run"):
		return
	if not _check(game.extra_lives == 0, "respawn consumes one extra life"):
		return
	if not _check(game.invincible_timer > 0.0, "respawn grants brief invincibility"):
		return
	if not _check(not overlay_label.visible, "extra life respawn does not show center text"):
		return

	if not _check(not game._segment_reaches_player(game.player_z - game.segment_depth * 0.45), "hazard check does not fire before the tile is under the player"):
		return
	if not _check(game._segment_reaches_player(game.player_z - 0.05), "hazard check fires near the player"):
		return

	game.reset_game()
	game.invincible_timer = 2.0
	game.jump_height = 0.3
	game.vertical_velocity = -12.0
	game.jump_buffer_timer = game.jump_buffer_seconds
	game._process(0.05)
	if not _check(game.vertical_velocity > 0.0, "queued jump triggers on landing"):
		return

	if not _check(game.shadow_visual != null and game.shadow_visual.visible, "player shadow is visible for orientation"):
		return

	game._game_over()
	if not _check(not game.is_alive, "game enters fail state first"):
		return
	if not _check(overlay_label.text.contains("PRESS R"), "game over waits for manual restart"):
		return
	game._process(game.auto_restart_seconds + 0.1)
	if not _check(not game.is_alive, "game stays stopped until restart input"):
		return

	game.free()
	print("test_electron_dash_game_behavior passed")
	quit(0)
