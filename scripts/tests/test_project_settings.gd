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
	var actions := ["move_left", "move_right", "jump", "duck", "restart"]
	for action in actions:
		if not _check(InputMap.has_action(action), "%s action exists" % action):
			return
		if not _check(InputMap.action_get_events(action).size() > 0, "%s has key events" % action):
			return
	if not _check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main/ElectronDashGame.tscn", "main scene points to tunnel runner"):
		return
	print("test_project_settings passed")
	quit(0)
