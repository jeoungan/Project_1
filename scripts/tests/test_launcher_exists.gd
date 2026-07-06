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
	if not _check(FileAccess.file_exists("res://집에 가고 싶다 실행.cmd"), "double-click launcher exists"):
		return
	if not _check(FileAccess.file_exists("res://집에 가고 싶다 실행.lnk"), "Windows shortcut exists"):
		return
	print("test_launcher_exists passed")
	quit(0)
