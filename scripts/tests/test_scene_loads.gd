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
	if not _check(packed != null, "main scene loads"):
		return
	var instance := packed.instantiate()
	if not _check(instance != null, "main scene instantiates"):
		return
	if not _check(instance.get_script() != null, "main scene script is attached"):
		return
	if not _check(instance.has_method("reset_game"), "main scene exposes reset_game"):
		return
	instance.free()
	print("test_scene_loads passed")
	quit(0)
