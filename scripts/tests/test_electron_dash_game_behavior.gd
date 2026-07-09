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
	var first_seed: int = game.map_seed
	game.reset_game()
	if not _check(game.map_seed != first_seed, "each run gets a fresh map seed"):
		return
	if not _check(game.segment_depth >= 3.2, "rows are spaced far enough to read gaps"):
		return
	if not _check(game._tile_depth(false) >= game.segment_depth * 1.02, "ordinary road tiles overlap into a continuous path"):
		return
	if not _check(game._panel_width(1.0) >= game._lane_surface_width() * 0.96, "each road face fills the whole lane surface"):
		return
	if not _check(game._edge_color().g > 0.6 and game._edge_color().b > 0.9, "lane dividers are bright sky blue"):
		return
	if not _check(not game._renders_warning_markers(), "red and blue warning strips are not rendered"):
		return
	if not _check(game._tile_border_color().b > 0.9 and game._tile_border_color().g > 0.8, "road panels have bright neon blue-white borders"):
		return
	if not _check(game._tile_pattern_color().b > 0.85 and game._tile_pattern_color().r < 0.1, "road panel pattern uses neon blue"):
		return
	if not _check(game._star_color().b > 0.95 and game._star_color().g > 0.8, "road panels have bright galaxy star dots"):
		return
	var stable_color: Color = game._tile_color(false)
	var unstable_color: Color = game._tile_color(true)
	if not _check(stable_color.b > 0.55 and stable_color.g > 0.16 and stable_color.r < 0.08, "stable tiles are vivid blue instead of black"):
		return
	if not _check(unstable_color.b >= stable_color.b and unstable_color.g > stable_color.g, "unstable tiles stay in the bright blue family"):
		return
	var panel_visual: Node3D = game._make_tile(0, 0, stable_color)
	if not _check(panel_visual.get_child_count() >= 24, "road panels include dense geometric linework and galaxy dots"):
		return
	panel_visual.free()
	if not _check(game.lane_turn_speed <= 9.0, "lane rotation is eased instead of snapping"):
		return
	var hint_label: Label = game.get_node("%HintLabel")
	if not _check(not hint_label.visible, "bottom key hint stays hidden"):
		return
	if not _check(game.player_visual.mesh is BoxMesh, "player is a simple cube"):
		return
	var box_mesh := game.player_visual.mesh as BoxMesh
	if not _check(is_equal_approx(box_mesh.size.x, box_mesh.size.y), "player cube has square front"):
		return
	if not _check(game._player_color().g > 0.7 and game._player_color().r < 0.2, "player cube base is neon green"):
		return
	if not _check(game._player_pattern_color().g > 0.9 and game._player_pattern_color().b > 0.6, "player cube has fluorescent geometric markings"):
		return
	if not _check(game.player_visual.get_child_count() >= 4, "player cube includes geometric surface markings"):
		return
	var spin_a: float = game._player_spin_angle()
	game.world_time = 0.5
	var spin_b: float = game._player_spin_angle()
	if not _check(abs(spin_a - spin_b) > 0.5, "player cube keeps rotating over time"):
		return
	game.world_time = 0.0
	var bob_a: float = game._player_bob_offset()
	game.world_time = 0.15
	var bob_b: float = game._player_bob_offset()
	if not _check(abs(bob_a - bob_b) > 0.03, "player cube has a bouncy idle bob"):
		return
	if not _check(game._is_portrait_view(Vector2(540.0, 960.0)), "mobile portrait view is detected"):
		return
	if not _check(not game._is_portrait_view(Vector2(1280.0, 720.0)), "desktop landscape view is detected"):
		return
	if not _check(game._target_camera_fov(Vector2(540.0, 960.0), 0.0) < game._target_camera_fov(Vector2(1280.0, 720.0), 0.0), "portrait camera uses a tighter vertical framing"):
		return
	if not _check(game._target_camera_z(Vector2(540.0, 960.0)) > game._target_camera_z(Vector2(1280.0, 720.0)), "portrait camera pulls back to show the tunnel"):
		return
	if not _check(game._target_camera_y(Vector2(540.0, 960.0)) > 0.0, "portrait camera keeps the player in the lower captured area"):
		return

	game.reset_game()
	game.player_lane = 2
	var right_touch := InputEventScreenTouch.new()
	right_touch.pressed = true
	right_touch.position = Vector2(220.0, 600.0)
	game._unhandled_input(right_touch)
	var right_drag := InputEventScreenDrag.new()
	right_drag.position = Vector2(340.0, 604.0)
	right_drag.relative = Vector2(120.0, 4.0)
	game._unhandled_input(right_drag)
	if not _check(game.player_lane == 3, "right swipe rotates one lane right"):
		return

	var left_touch := InputEventScreenTouch.new()
	left_touch.pressed = true
	left_touch.position = Vector2(340.0, 604.0)
	game._unhandled_input(left_touch)
	var left_drag := InputEventScreenDrag.new()
	left_drag.position = Vector2(200.0, 604.0)
	left_drag.relative = Vector2(-140.0, 0.0)
	game._unhandled_input(left_drag)
	if not _check(game.player_lane == 2, "left swipe rotates one lane left"):
		return

	game.reset_game()
	var up_touch := InputEventScreenTouch.new()
	up_touch.pressed = true
	up_touch.position = Vector2(260.0, 620.0)
	game._unhandled_input(up_touch)
	var up_drag := InputEventScreenDrag.new()
	up_drag.position = Vector2(260.0, 480.0)
	up_drag.relative = Vector2(0.0, -140.0)
	game._unhandled_input(up_drag)
	if not _check(game.vertical_velocity > 0.0, "up swipe jumps on mobile"):
		return

	game.reset_game()
	game.player_lane = 1
	var small_touch := InputEventScreenTouch.new()
	small_touch.pressed = true
	small_touch.position = Vector2(260.0, 620.0)
	game._unhandled_input(small_touch)
	var small_drag := InputEventScreenDrag.new()
	small_drag.position = Vector2(280.0, 620.0)
	small_drag.relative = Vector2(20.0, 0.0)
	game._unhandled_input(small_drag)
	if not _check(game.player_lane == 1, "tiny drags do not trigger mobile movement"):
		return

	game.world_time = 0.0
	var mover_offset_a: float = game._mover_offset(0)
	game.world_time = 0.6
	var mover_offset_b: float = game._mover_offset(0)
	if not _check(abs(mover_offset_a - mover_offset_b) > 0.05, "moving obstacle sweeps across a face over time"):
		return
	var mover_visual: Node3D = game._make_moving_obstacle(0)
	if not _check(mover_visual.get_child_count() >= 2, "moving obstacle has a layered spike silhouette"):
		return
	var spike_mesh := (mover_visual.get_child(0) as MeshInstance3D).mesh
	if not _check(spike_mesh is ArrayMesh, "moving obstacle uses a pointed triangular prism mesh"):
		return
	mover_visual.free()

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
	var overlay_label: Label = game.get_node("%OverlayLabel")
	var overlay_backdrop := game.get_node_or_null("%OverlayBackdrop") as ColorRect
	if not _check(overlay_backdrop != null, "game over has a visible background panel"):
		return
	if not _check(not overlay_backdrop.visible, "game over background starts hidden"):
		return
	game._change_lane(1)
	if not _check(game.lane_change_grace_timer > 0.0, "lane changes get a short collision grace window"):
		return
	if not _check(not game._hazards_are_active(), "hazards pause while the lane is rotating"):
		return
	game._process(game.lane_change_grace_seconds + 0.05)
	if not _check(game._hazards_are_active(), "hazards resume after lane rotation grace"):
		return

	if not _check(not game._segment_reaches_player(game.player_z - game.segment_depth * 0.45), "hazard check does not fire before the tile is under the player"):
		return
	if not _check(game._segment_reaches_player(game.player_z - 0.05), "hazard check fires near the player"):
		return

	game.reset_game()
	game.invincible_timer = 0.0
	game.player_lane = 0
	game.jump_height = 0.0
	game.lane_change_grace_timer = game.lane_change_grace_seconds
	var fall_segment: Dictionary = game.segments[0]
	(fall_segment["root"] as Node3D).position.z = game.player_z
	fall_segment["checked"] = false
	fall_segment["data"] = {
		"floors": [false, true, true, true, true],
		"lasers": [false, false, false, false, false],
		"unstable": [false, false, false, false, false],
		"movers": [false, false, false, false, false],
		"jump_markers": [false, false, false, false, false],
		"blocked_markers": [false, false, false, false, false]
	}
	game.segments[0] = fall_segment
	game._scroll_segments(0.0, 0.0)
	if not _check(not game.is_alive, "missing floor still kills during lane rotation grace"):
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

	game.score = 17
	game._game_over()
	if not _check(not game.is_alive, "game enters fail state first"):
		return
	if not _check(overlay_backdrop.visible, "game over background becomes visible"):
		return
	if not _check(overlay_backdrop.color.a >= 0.65, "game over background is readable"):
		return
	if not _check(overlay_label.text.contains("17초"), "game over shows survived seconds"):
		return
	if not _check(overlay_label.text.contains("R"), "game over tells the player to press R"):
		return
	if not _check(overlay_label.get_theme_font_size("font_size") >= 30, "game over text is large enough to read"):
		return
	game._process(game.auto_restart_seconds + 0.1)
	if not _check(not game.is_alive, "game stays stopped until restart input"):
		return
	var restart_touch := InputEventScreenTouch.new()
	restart_touch.pressed = true
	restart_touch.position = Vector2(240.0, 520.0)
	game._unhandled_input(restart_touch)
	if not _check(game.is_alive and not overlay_backdrop.visible, "tap restarts after game over on mobile"):
		return

	game.free()
	print("test_electron_dash_game_behavior passed")
	quit(0)
