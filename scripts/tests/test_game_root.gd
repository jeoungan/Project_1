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
	var game = load("res://scripts/core/game_root.gd").new()
	game.set_mode_for_test("IntroCutscene")
	game.advance_for_test()
	if not _check(game.mode == "Runner", "intro advances to runner"):
		return
	game.advance_for_test()
	if not _check(game.mode == "Boss", "runner advances to boss"):
		return
	game.advance_for_test()
	if not _check(game.mode == "EndingCutscene", "boss advances to ending"):
		return
	game.free()
	print("test_game_root passed")
	quit(0)
