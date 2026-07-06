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
	var meter = load("res://scripts/core/desire_meter.gd").new()
	root.add_child(meter)

	var change_count := [0]
	var burst_started := [false]
	var burst_ended := [false]

	meter.changed.connect(func(_value: int, _max_value: int) -> void:
		change_count[0] += 1
	)
	meter.burst_started.connect(func() -> void:
		burst_started[0] = true
	)
	meter.burst_ended.connect(func() -> void:
		burst_ended[0] = true
	)

	if not _check(meter.value == 0, "meter starts empty"):
		return
	meter.add_value(40)
	if not _check(meter.value == 40, "meter adds value"):
		return
	meter.add_value(80)
	if not _check(meter.value == 100, "meter clamps to max"):
		return
	if not _check(meter.is_bursting, "meter starts burst at max"):
		return
	if not _check(burst_started[0], "burst_started signal emitted"):
		return
	if not _check(change_count[0] >= 2, "changed signal emitted"):
		return
	if not _check(meter.consume_special(), "special can be consumed while bursting"):
		return
	if not _check(meter.value == 0, "special clears meter"):
		return
	if not _check(not meter.is_bursting, "special ends burst"):
		return
	if not _check(burst_ended[0], "burst_ended signal emitted"):
		return

	print("test_desire_meter passed")
	quit(0)
