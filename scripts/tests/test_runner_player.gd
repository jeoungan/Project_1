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
	var player = load("res://scripts/runner/runner_player.gd").new()
	root.add_child(player)

	if not _check(player.lane_index == 1, "player starts in center lane"):
		return
	if not _check(player.move_lane(-1), "player moves left"):
		return
	if not _check(player.lane_index == 0, "left lane index applied"):
		return
	if not _check(not player.move_lane(-1), "player cannot move beyond left lane"):
		return
	if not _check(player.try_jump(), "first jump succeeds"):
		return
	if not _check(player.try_jump(), "double jump succeeds"):
		return
	if not _check(not player.try_jump(), "third jump fails"):
		return
	player.land()
	if not _check(player.jump_count == 0, "landing resets jump count"):
		return
	player.set_ducking(true)
	if not _check(player.is_ducking, "ducking starts"):
		return
	player.apply_hit(1)
	if not _check(player.health == 2, "hit removes health"):
		return

	print("test_runner_player passed")
	quit(0)
