class_name GameRoot
extends Node

const CUTSCENE_SCENE := preload("res://scenes/cutscenes/CutscenePlayer.tscn")
const RUNNER_SCENE := preload("res://scenes/runner/RunnerStage.tscn")

var mode: String = ""
var current_scene: Node = null
var scene_root: Node = null

func _ready() -> void:
	scene_root = get_node_or_null("%SceneRoot")
	start_intro()

func set_mode_for_test(new_mode: String) -> void:
	mode = new_mode

func advance_for_test() -> void:
	if mode == "IntroCutscene":
		mode = "Runner"
	elif mode == "Runner":
		mode = "Boss"
	elif mode == "Boss":
		mode = "EndingCutscene"

func start_intro() -> void:
	mode = "IntroCutscene"
	var cutscene = CUTSCENE_SCENE.instantiate()
	_swap_scene(cutscene)
	cutscene.configure("종례를 뚫고 집으로", PackedStringArray([
		"시계는 멈춘 것 같다.",
		"종례는 끝나지 않는다.",
		"집에 가고 싶다."
	]))
	cutscene.completed.connect(start_runner)

func start_runner() -> void:
	mode = "Runner"
	var runner = RUNNER_SCENE.instantiate()
	_swap_scene(runner)
	runner.stage_completed.connect(start_boss)
	runner.player_defeated.connect(start_runner)

func start_boss() -> void:
	mode = "Boss"
	var boss_scene: PackedScene = load("res://scenes/boss/BossArena.tscn")
	if boss_scene == null:
		return
	var boss = boss_scene.instantiate()
	_swap_scene(boss)
	boss.boss_defeated.connect(start_ending)
	boss.player_defeated.connect(start_boss)

func start_ending() -> void:
	mode = "EndingCutscene"
	var cutscene = CUTSCENE_SCENE.instantiate()
	_swap_scene(cutscene)
	cutscene.configure("탈출", PackedStringArray([
		"교문이 열린다.",
		"빛이 보인다.",
		"오늘은 집에 간다."
	]))

func _swap_scene(next_scene: Node) -> void:
	if current_scene:
		current_scene.queue_free()
	current_scene = next_scene
	if scene_root:
		scene_root.add_child(current_scene)
