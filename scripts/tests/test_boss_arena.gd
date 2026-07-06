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
	var boss = load("res://scripts/boss/homeroom_boss.gd").new()
	root.add_child(boss)
	boss.max_health = 30
	boss.health = 30

	var defeat_count := [0]
	boss.defeated.connect(func() -> void:
		defeat_count[0] += 1
	)

	boss.take_damage(10)
	if not _check(boss.health == 20, "boss takes damage"):
		return
	boss.take_damage(25)
	if not _check(boss.health == 0, "boss health clamps at zero"):
		return
	boss.take_damage(25)
	if not _check(defeat_count[0] == 1, "boss defeat signal emitted once"):
		return

	boss.free()

	var player = load("res://scripts/boss/boss_player.gd").new()
	root.add_child(player)
	player.set_ducking(true)
	if not _check(player.is_ducking, "boss player can duck"):
		return
	player.free()

	print("test_boss_arena passed")
	quit(0)
