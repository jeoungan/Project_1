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
	var required_dirs := [
		"res://scenes/main",
		"res://scenes/cutscenes",
		"res://scenes/runner",
		"res://scenes/ui",
		"res://scenes/boss",
		"res://scripts/core",
		"res://scripts/runner",
		"res://scripts/ui",
		"res://scripts/boss",
		"res://scripts/tests",
		"res://assets/art",
		"res://assets/audio",
		"res://assets/cutscenes",
		"res://resources"
	]
	for path in required_dirs:
		if not _check(DirAccess.dir_exists_absolute(path), "%s is missing" % path):
			return
	print("test_project_loads passed")
	quit(0)
