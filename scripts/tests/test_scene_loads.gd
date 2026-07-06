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
	var scene_paths := [
		"res://scenes/main/GameRoot.tscn",
		"res://scenes/cutscenes/CutscenePlayer.tscn",
		"res://scenes/runner/RunnerStage.tscn",
		"res://scenes/runner/RunnerPlayer.tscn",
		"res://scenes/runner/Obstacle.tscn",
		"res://scenes/ui/HUD.tscn",
		"res://scenes/boss/BossArena.tscn",
		"res://scenes/boss/BossPlayer.tscn",
		"res://scenes/boss/HomeroomBoss.tscn",
		"res://scenes/boss/BossProjectile.tscn"
	]
	for path in scene_paths:
		var packed: PackedScene = load(path)
		if not _check(packed != null, "%s loads" % path):
			return
		var instance := packed.instantiate()
		if not _check(instance != null, "%s instantiates" % path):
			return
		instance.free()

	print("test_scene_loads passed")
	quit(0)
