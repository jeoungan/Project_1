# School Tunnel Runner Chapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first playable Godot 4 chapter for `집에 가고 싶다`: a school-themed Electron Dash-inspired 2.5D runner that transitions into an action boss fight.

**Architecture:** The game is a small Godot 4 project with a stateful `GameRoot` that switches between intro cutscene, runner stage, boss arena, and ending cutscene. Runner and boss systems share player input concepts but live in separate scenes so the endless-runner feel and free-movement boss fight can evolve independently.

**Tech Stack:** Godot 4.x, GDScript, built-in 2D nodes, text-based `.tscn` scenes, headless Godot script tests, no external assets for the first playable slice.

---

## File Structure

- `.gitignore`: Godot import/cache ignores.
- `project.godot`: Godot project settings, input map, launch scene.
- `scenes/main/GameRoot.tscn`: Main scene that owns chapter state transitions.
- `scenes/cutscenes/CutscenePlayer.tscn`: Reusable simple cutscene scene.
- `scenes/runner/RunnerStage.tscn`: Runner gameplay scene.
- `scenes/runner/RunnerPlayer.tscn`: Runner player scene with hitbox and visual shape.
- `scenes/runner/Obstacle.tscn`: Generic runner obstacle scene.
- `scenes/ui/HUD.tscn`: In-game HUD scene.
- `scenes/boss/BossArena.tscn`: Free-movement boss scene.
- `scenes/boss/BossPlayer.tscn`: Boss-fight player scene.
- `scenes/boss/HomeroomBoss.tscn`: Homeroom teacher boss scene.
- `scenes/boss/BossProjectile.tscn`: Boss projectile scene.
- `scripts/core/desire_meter.gd`: Shared desire gauge and burst-mode state.
- `scripts/core/game_root.gd`: Chapter state machine and scene swapping.
- `scripts/core/cutscene_player.gd`: Simple scene-based cutscene playback.
- `scripts/runner/runner_player.gd`: Runner lane movement, jump, double jump, duck, health.
- `scripts/runner/lane_tunnel_view.gd`: 2.5D tunnel lane rendering and motion.
- `scripts/runner/obstacle.gd`: Runner obstacle behavior and metadata.
- `scripts/runner/obstacle_spawner.gd`: Distance-based runner pattern spawner.
- `scripts/runner/runner_stage.gd`: Runner stage flow, distance, collisions, transition signal.
- `scripts/ui/hud.gd`: Health, distance, and desire gauge display.
- `scripts/boss/boss_player.gd`: Free-movement boss player controls and attacks.
- `scripts/boss/homeroom_boss.gd`: Boss health, pattern cycle, vulnerable windows.
- `scripts/boss/boss_projectile.gd`: Boss projectile movement and hit metadata.
- `scripts/boss/boss_arena.gd`: Boss fight orchestration and defeat transition.
- `scripts/tests/test_project_loads.gd`: Project scaffold smoke test.
- `scripts/tests/test_desire_meter.gd`: Desire meter behavior test.
- `scripts/tests/test_runner_player.gd`: Runner player movement state test.
- `scripts/tests/test_obstacle_spawner.gd`: Pattern scheduling test.
- `scripts/tests/test_runner_stage.gd`: Runner stage completion and damage routing test.
- `scripts/tests/test_game_root.gd`: Game state transition test.
- `scripts/tests/test_boss_arena.gd`: Boss fight defeat flow test.

## Shared Test Pattern

All test scripts extend `SceneTree`, print a passing message, and call `quit(0)`. Failure paths call `printerr()` and `quit(1)`.

Use this helper shape in every test file:

```gdscript
extends SceneTree

func _fail(message: String) -> void:
    printerr(message)
    quit(1)

func _check(condition: bool, message: String) -> bool:
    if not condition:
        _fail(message)
        return false
    return true
```

Run individual tests with:

```powershell
godot --headless --path . --script res://scripts/tests/test_name.gd
```

Expected passing output always includes the test name followed by `passed`.

### Task 1: Godot Project Scaffold

**Files:**
- Create: `.gitignore`
- Create: `project.godot`
- Create: `scripts/tests/test_project_loads.gd`
- Create directories: `scenes/main`, `scenes/cutscenes`, `scenes/runner`, `scenes/ui`, `scenes/boss`, `scripts/core`, `scripts/runner`, `scripts/ui`, `scripts/boss`, `scripts/tests`, `assets/art`, `assets/audio`, `assets/cutscenes`, `resources`

- [ ] **Step 1: Create directories**

Run:

```powershell
New-Item -ItemType Directory -Force scenes/main, scenes/cutscenes, scenes/runner, scenes/ui, scenes/boss, scripts/core, scripts/runner, scripts/ui, scripts/boss, scripts/tests, assets/art, assets/audio, assets/cutscenes, resources
```

Expected: PowerShell lists the created directories without errors.

- [ ] **Step 2: Create `.gitignore`**

Write:

```gitignore
.godot/
*.tmp
*.translation
export.cfg
export_presets.cfg
```

- [ ] **Step 3: Create `project.godot`**

Write:

```ini
; Engine configuration file.
; Editing this file by hand is allowed for the first scaffold.

config_version=5

[application]

config/name="집에 가고 싶다"
run/main_scene="res://scenes/main/GameRoot.tscn"
config/features=PackedStringArray("4.3", "Forward Plus")
config/icon="res://icon.svg"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[input]

move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":65,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)]
}
move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":68,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)]
}
jump={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":32,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)]
}
duck={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":83,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)]
}
attack={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":90,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)]
}
dash={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":true,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194325,"physical_keycode":0,"key_label":0,"unicode":0,"echo":false,"script":null)]
}
```

- [ ] **Step 4: Write the scaffold smoke test**

Create `scripts/tests/test_project_loads.gd`:

```gdscript
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
```

- [ ] **Step 5: Run scaffold smoke test**

Run:

```powershell
godot --headless --path . --script res://scripts/tests/test_project_loads.gd
```

Expected: `test_project_loads passed`

- [ ] **Step 6: Commit scaffold**

Run:

```powershell
git add .gitignore project.godot scripts/tests/test_project_loads.gd
git commit -m "chore: scaffold Godot project"
```

Expected: commit succeeds.

### Task 2: Desire Meter

**Files:**
- Create: `scripts/core/desire_meter.gd`
- Create: `scripts/tests/test_desire_meter.gd`

- [ ] **Step 1: Write the failing desire meter test**

Create `scripts/tests/test_desire_meter.gd`:

```gdscript
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
    var meter := load("res://scripts/core/desire_meter.gd").new()
    root.add_child(meter)

    var change_count := 0
    var burst_started := false
    var burst_ended := false

    meter.changed.connect(func(_value: int, _max_value: int) -> void:
        change_count += 1
    )
    meter.burst_started.connect(func() -> void:
        burst_started = true
    )
    meter.burst_ended.connect(func() -> void:
        burst_ended = true
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
    if not _check(burst_started, "burst_started signal emitted"):
        return
    if not _check(change_count >= 2, "changed signal emitted"):
        return
    if not _check(meter.consume_special(), "special can be consumed while bursting"):
        return
    if not _check(meter.value == 0, "special clears meter"):
        return
    if not _check(not meter.is_bursting, "special ends burst"):
        return
    if not _check(burst_ended, "burst_ended signal emitted"):
        return

    print("test_desire_meter passed")
    quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
godot --headless --path . --script res://scripts/tests/test_desire_meter.gd
```

Expected: FAIL because `res://scripts/core/desire_meter.gd` does not exist.

- [ ] **Step 3: Implement `DesireMeter`**

Create `scripts/core/desire_meter.gd`:

```gdscript
class_name DesireMeter
extends Node

signal changed(value: int, max_value: int)
signal burst_started
signal burst_ended

@export var max_value: int = 100
@export var burst_seconds: float = 4.0

var value: int = 0
var is_bursting: bool = false
var burst_time_left: float = 0.0

func add_value(amount: int) -> void:
    if amount <= 0:
        return
    value = clamp(value + amount, 0, max_value)
    changed.emit(value, max_value)
    if value >= max_value and not is_bursting:
        start_burst()

func start_burst() -> void:
    is_bursting = true
    burst_time_left = burst_seconds
    burst_started.emit()

func consume_special() -> bool:
    if value < max_value and not is_bursting:
        return false
    value = 0
    changed.emit(value, max_value)
    if is_bursting:
        is_bursting = false
        burst_time_left = 0.0
        burst_ended.emit()
    return true

func reset_to_half() -> void:
    value = int(max_value * 0.5)
    is_bursting = false
    burst_time_left = 0.0
    changed.emit(value, max_value)

func _process(delta: float) -> void:
    if not is_bursting:
        return
    burst_time_left -= delta
    if burst_time_left <= 0.0:
        is_bursting = false
        burst_time_left = 0.0
        burst_ended.emit()
```

- [ ] **Step 4: Run desire meter test**

Run:

```powershell
godot --headless --path . --script res://scripts/tests/test_desire_meter.gd
```

Expected: `test_desire_meter passed`

- [ ] **Step 5: Commit desire meter**

Run:

```powershell
git add scripts/core/desire_meter.gd scripts/tests/test_desire_meter.gd
git commit -m "feat: add desire meter"
```

Expected: commit succeeds.

### Task 3: Runner Player Movement State

**Files:**
- Create: `scripts/runner/runner_player.gd`
- Create: `scripts/tests/test_runner_player.gd`
- Create: `scenes/runner/RunnerPlayer.tscn`

- [ ] **Step 1: Write the failing runner player test**

Create `scripts/tests/test_runner_player.gd`:

```gdscript
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
    var player := load("res://scripts/runner/runner_player.gd").new()
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
godot --headless --path . --script res://scripts/tests/test_runner_player.gd
```

Expected: FAIL because `runner_player.gd` does not exist.

- [ ] **Step 3: Implement runner player script**

Create `scripts/runner/runner_player.gd`:

```gdscript
class_name RunnerPlayer
extends Area2D

signal damaged(health: int)
signal defeated
signal desire_collected(amount: int)

@export var lane_positions: PackedFloat32Array = PackedFloat32Array([-260.0, 0.0, 260.0])
@export var ground_y: float = 500.0
@export var jump_speed: float = -760.0
@export var gravity: float = 2100.0
@export var lane_lerp_speed: float = 16.0

var lane_index: int = 1
var jump_count: int = 0
var vertical_velocity: float = 0.0
var y_offset: float = 0.0
var is_ducking: bool = false
var health: int = 3

func _ready() -> void:
    position = Vector2(lane_positions[lane_index], ground_y)

func move_lane(direction: int) -> bool:
    var next_lane := clamp(lane_index + direction, 0, lane_positions.size() - 1)
    if next_lane == lane_index:
        return false
    lane_index = next_lane
    return true

func try_jump() -> bool:
    if jump_count >= 2:
        return false
    jump_count += 1
    vertical_velocity = jump_speed
    is_ducking = false
    return true

func land() -> void:
    jump_count = 0
    vertical_velocity = 0.0
    y_offset = 0.0

func set_ducking(active: bool) -> void:
    if jump_count > 0 and active:
        return
    is_ducking = active

func apply_hit(damage: int) -> void:
    health = max(health - damage, 0)
    damaged.emit(health)
    if health == 0:
        defeated.emit()

func collect_desire(amount: int) -> void:
    desire_collected.emit(amount)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("move_left"):
        move_lane(-1)
    if event.is_action_pressed("move_right"):
        move_lane(1)
    if event.is_action_pressed("jump"):
        try_jump()
    if event.is_action_pressed("duck"):
        set_ducking(true)
    if event.is_action_released("duck"):
        set_ducking(false)

func _physics_process(delta: float) -> void:
    vertical_velocity += gravity * delta
    y_offset += vertical_velocity * delta
    if y_offset > 0.0:
        land()
    var target_x := lane_positions[lane_index]
    var target_y := ground_y + y_offset
    position.x = lerp(position.x, target_x, min(1.0, lane_lerp_speed * delta))
    position.y = target_y
```

- [ ] **Step 4: Create runner player scene**

Create `scenes/runner/RunnerPlayer.tscn`:

```ini
[gd_scene load_steps=3 format=3 uid="uid://runner_player_scene"]

[ext_resource type="Script" path="res://scripts/runner/runner_player.gd" id="1"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_runner_hitbox"]
size = Vector2(64, 96)

[node name="RunnerPlayer" type="Area2D"]
script = ExtResource("1")

[node name="Body" type="Polygon2D" parent="."]
color = Color(0.2, 0.72, 1, 1)
polygon = PackedVector2Array(-30, 0, 30, 0, 24, -86, -22, -96)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, -48)
shape = SubResource("RectangleShape2D_runner_hitbox")
```

- [ ] **Step 5: Run runner player test**

Run:

```powershell
godot --headless --path . --script res://scripts/tests/test_runner_player.gd
```

Expected: `test_runner_player passed`

- [ ] **Step 6: Commit runner player**

Run:

```powershell
git add scripts/runner/runner_player.gd scripts/tests/test_runner_player.gd scenes/runner/RunnerPlayer.tscn
git commit -m "feat: add runner player controls"
```

Expected: commit succeeds.

### Task 4: Runner Tunnel View and HUD

**Files:**
- Create: `scripts/runner/lane_tunnel_view.gd`
- Create: `scripts/ui/hud.gd`
- Create: `scenes/ui/HUD.tscn`

- [ ] **Step 1: Implement lane tunnel view**

Create `scripts/runner/lane_tunnel_view.gd`:

```gdscript
class_name LaneTunnelView
extends Node2D

@export var lane_positions: PackedFloat32Array = PackedFloat32Array([-260.0, 0.0, 260.0])
@export var horizon_y: float = 130.0
@export var floor_y: float = 575.0
@export var scroll_speed: float = 260.0

var scroll_offset: float = 0.0
var twist: float = 0.0
var burst_strength: float = 0.0

func set_twist_from_lane(lane_index: int) -> void:
    twist = float(lane_index - 1) * 0.08

func set_burst(active: bool) -> void:
    burst_strength = 1.0 if active else 0.0

func _process(delta: float) -> void:
    scroll_offset = fmod(scroll_offset + scroll_speed * delta, 120.0)
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2(-700, -80), Vector2(1400, 800)), Color(0.04, 0.05, 0.1))
    var glow := Color(0.18 + burst_strength * 0.35, 0.45, 0.75 + burst_strength * 0.2, 0.4)
    for i in range(12):
        var t := float(i) / 11.0
        var y := lerp(horizon_y, floor_y, t)
        var width := lerp(160.0, 1150.0, t)
        var x_shift := sin(t * 4.0 + scroll_offset * 0.02) * 24.0 + twist * 420.0 * t
        draw_line(Vector2(-width * 0.5 + x_shift, y), Vector2(width * 0.5 + x_shift, y), glow, 3.0)
    for lane_x in lane_positions:
        draw_line(Vector2(lane_x * 0.2, horizon_y), Vector2(lane_x, floor_y), Color(0.45, 0.85, 1.0, 0.55), 4.0)
```

- [ ] **Step 2: Implement HUD script**

Create `scripts/ui/hud.gd`:

```gdscript
class_name HUD
extends CanvasLayer

@onready var health_label: Label = %HealthLabel
@onready var distance_label: Label = %DistanceLabel
@onready var desire_bar: ProgressBar = %DesireBar
@onready var status_label: Label = %StatusLabel

func set_health(value: int) -> void:
    health_label.text = "HP %d" % value

func set_distance(value: float, target: float) -> void:
    distance_label.text = "%04dm / %04dm" % [int(value), int(target)]

func set_desire(value: int, max_value: int) -> void:
    desire_bar.max_value = max_value
    desire_bar.value = value

func set_status(text: String) -> void:
    status_label.text = text
```

- [ ] **Step 3: Create HUD scene**

Create `scenes/ui/HUD.tscn`:

```ini
[gd_scene load_steps=2 format=3 uid="uid://hud_scene"]

[ext_resource type="Script" path="res://scripts/ui/hud.gd" id="1"]

[node name="HUD" type="CanvasLayer"]
script = ExtResource("1")

[node name="Panel" type="Panel" parent="."]
anchors_preset = 10
anchor_right = 1.0
offset_bottom = 82.0

[node name="HealthLabel" type="Label" parent="Panel"]
unique_name_in_owner = true
offset_left = 24.0
offset_top = 18.0
offset_right = 160.0
offset_bottom = 48.0
text = "HP 3"

[node name="DistanceLabel" type="Label" parent="Panel"]
unique_name_in_owner = true
offset_left = 520.0
offset_top = 18.0
offset_right = 760.0
offset_bottom = 48.0
horizontal_alignment = 1
text = "0000m / 1200m"

[node name="DesireBar" type="ProgressBar" parent="Panel"]
unique_name_in_owner = true
offset_left = 930.0
offset_top = 18.0
offset_right = 1220.0
offset_bottom = 44.0
max_value = 100.0
value = 0.0

[node name="StatusLabel" type="Label" parent="Panel"]
unique_name_in_owner = true
offset_left = 930.0
offset_top = 46.0
offset_right = 1220.0
offset_bottom = 74.0
text = ""
```

- [ ] **Step 4: Run existing tests**

Run:

```powershell
godot --headless --path . --script res://scripts/tests/test_project_loads.gd
godot --headless --path . --script res://scripts/tests/test_desire_meter.gd
godot --headless --path . --script res://scripts/tests/test_runner_player.gd
```

Expected: all three tests print `passed`.

- [ ] **Step 5: Commit tunnel view and HUD**

Run:

```powershell
git add scripts/runner/lane_tunnel_view.gd scripts/ui/hud.gd scenes/ui/HUD.tscn
git commit -m "feat: add runner tunnel view and HUD"
```

Expected: commit succeeds.

### Task 5: Obstacles and Pattern Spawner

**Files:**
- Create: `scripts/runner/obstacle.gd`
- Create: `scripts/runner/obstacle_spawner.gd`
- Create: `scripts/tests/test_obstacle_spawner.gd`
- Create: `scenes/runner/Obstacle.tscn`

- [ ] **Step 1: Write failing spawner test**

Create `scripts/tests/test_obstacle_spawner.gd`:

```gdscript
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
    var spawner := load("res://scripts/runner/obstacle_spawner.gd").new()
    root.add_child(spawner)
    spawner.patterns = [
        {"distance": 10.0, "kind": "desk", "lane": 1, "height": "ground"},
        {"distance": 20.0, "kind": "paper_laser", "lane": 0, "height": "high"}
    ]

    var spawned: Array = []
    spawner.spawn_requested.connect(func(definition: Dictionary) -> void:
        spawned.append(definition)
    )

    spawner.poll(9.0)
    if not _check(spawned.size() == 0, "no spawn before first distance"):
        return
    spawner.poll(10.0)
    if not _check(spawned.size() == 1, "first spawn at threshold"):
        return
    if not _check(spawned[0]["kind"] == "desk", "first spawn kind"):
        return
    spawner.poll(25.0)
    if not _check(spawned.size() == 2, "second spawn after threshold"):
        return

    print("test_obstacle_spawner passed")
    quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
godot --headless --path . --script res://scripts/tests/test_obstacle_spawner.gd
```

Expected: FAIL because `obstacle_spawner.gd` does not exist.

- [ ] **Step 3: Implement obstacle spawner**

Create `scripts/runner/obstacle_spawner.gd`:

```gdscript
class_name ObstacleSpawner
extends Node

signal spawn_requested(definition: Dictionary)

var patterns: Array[Dictionary] = [
    {"distance": 80.0, "kind": "desk", "lane": 1, "height": "ground"},
    {"distance": 180.0, "kind": "shockwave", "lane": 1, "height": "low"},
    {"distance": 300.0, "kind": "falling_tile", "lane": 0, "height": "ground"},
    {"distance": 430.0, "kind": "paper_laser", "lane": 2, "height": "high"},
    {"distance": 560.0, "kind": "chalk", "lane": 0, "height": "mid"},
    {"distance": 680.0, "kind": "key", "lane": 2, "height": "item"},
    {"distance": 820.0, "kind": "desk", "lane": 0, "height": "ground"},
    {"distance": 940.0, "kind": "shockwave", "lane": 2, "height": "low"},
    {"distance": 1060.0, "kind": "paper_laser", "lane": 1, "height": "high"}
]

var next_index: int = 0

func reset() -> void:
    next_index = 0

func poll(distance: float) -> void:
    while next_index < patterns.size() and distance >= float(patterns[next_index]["distance"]):
        spawn_requested.emit(patterns[next_index])
        next_index += 1
```

- [ ] **Step 4: Implement obstacle behavior**

Create `scripts/runner/obstacle.gd`:

```gdscript
class_name RunnerObstacle
extends Area2D

@export var kind: String = "desk"
@export var lane: int = 1
@export var height_tag: String = "ground"
@export var speed: float = 420.0
@export var damage: int = 1
@export var desire_value: int = 20

var is_collectible: bool = false

func configure(definition: Dictionary, lane_x: float, start_y: float) -> void:
    kind = str(definition.get("kind", "desk"))
    lane = int(definition.get("lane", 1))
    height_tag = str(definition.get("height", "ground"))
    is_collectible = kind == "key"
    position = Vector2(lane_x, start_y)
    _apply_visual()

func _apply_visual() -> void:
    var body := get_node_or_null("Body")
    if body is ColorRect:
        body.color = Color(1.0, 0.85, 0.25) if is_collectible else Color(1.0, 0.25, 0.25)

func _process(delta: float) -> void:
    position.y += speed * delta
    if position.y > 780.0:
        queue_free()
```

- [ ] **Step 5: Create obstacle scene**

Create `scenes/runner/Obstacle.tscn`:

```ini
[gd_scene load_steps=3 format=3 uid="uid://runner_obstacle_scene"]

[ext_resource type="Script" path="res://scripts/runner/obstacle.gd" id="1"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_obstacle"]
size = Vector2(76, 76)

[node name="Obstacle" type="Area2D"]
script = ExtResource("1")

[node name="Body" type="ColorRect" parent="."]
offset_left = -38.0
offset_top = -76.0
offset_right = 38.0
offset_bottom = 0.0
color = Color(1, 0.25, 0.25, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, -38)
shape = SubResource("RectangleShape2D_obstacle")
```

- [ ] **Step 6: Run spawner test**

Run:

```powershell
godot --headless --path . --script res://scripts/tests/test_obstacle_spawner.gd
```

Expected: `test_obstacle_spawner passed`

- [ ] **Step 7: Commit obstacles and spawner**

Run:

```powershell
git add scripts/runner/obstacle.gd scripts/runner/obstacle_spawner.gd scripts/tests/test_obstacle_spawner.gd scenes/runner/Obstacle.tscn
git commit -m "feat: add runner obstacles and spawner"
```

Expected: commit succeeds.

### Task 6: Runner Stage

**Files:**
- Create: `scripts/runner/runner_stage.gd`
- Create: `scripts/tests/test_runner_stage.gd`
- Create: `scenes/runner/RunnerStage.tscn`

- [ ] **Step 1: Write failing runner stage test**

Create `scripts/tests/test_runner_stage.gd`:

```gdscript
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
    var stage := load("res://scripts/runner/runner_stage.gd").new()
    root.add_child(stage)
    stage.target_distance = 100.0
    stage.base_speed = 50.0

    var completed := false
    stage.stage_completed.connect(func() -> void:
        completed = true
    )

    stage.advance_distance(1.0)
    if not _check(stage.distance == 50.0, "distance advances by speed"):
        return
    stage.advance_distance(1.0)
    if not _check(completed, "stage completes at target distance"):
        return

    print("test_runner_stage passed")
    quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
godot --headless --path . --script res://scripts/tests/test_runner_stage.gd
```

Expected: FAIL because `runner_stage.gd` does not exist.

- [ ] **Step 3: Implement runner stage**

Create `scripts/runner/runner_stage.gd`:

```gdscript
class_name RunnerStage
extends Node2D

signal stage_completed
signal player_defeated

const OBSTACLE_SCENE := preload("res://scenes/runner/Obstacle.tscn")

@export var target_distance: float = 1200.0
@export var base_speed: float = 260.0
@export var burst_speed_bonus: float = 120.0

var distance: float = 0.0
var is_running: bool = true

@onready var tunnel: LaneTunnelView = %LaneTunnelView
@onready var player: RunnerPlayer = %RunnerPlayer
@onready var obstacle_root: Node2D = %ObstacleRoot
@onready var spawner: ObstacleSpawner = %ObstacleSpawner
@onready var meter: DesireMeter = %DesireMeter
@onready var hud: HUD = %HUD

func _ready() -> void:
    if spawner:
        spawner.spawn_requested.connect(_spawn_obstacle)
    if player:
        player.damaged.connect(func(health: int) -> void:
            hud.set_health(health)
        )
        player.defeated.connect(func() -> void:
            is_running = false
            player_defeated.emit()
        )
        player.desire_collected.connect(func(amount: int) -> void:
            meter.add_value(amount)
        )
        player.area_entered.connect(_on_player_area_entered)
    if meter:
        meter.changed.connect(func(value: int, max_value: int) -> void:
            hud.set_desire(value, max_value)
        )
        meter.burst_started.connect(func() -> void:
            hud.set_status("폭주 모드")
            tunnel.set_burst(true)
        )
        meter.burst_ended.connect(func() -> void:
            hud.set_status("")
            tunnel.set_burst(false)
        )
    hud.set_health(player.health)
    hud.set_distance(distance, target_distance)
    hud.set_desire(meter.value, meter.max_value)

func advance_distance(delta: float) -> void:
    if not is_running:
        return
    var speed := base_speed
    if meter and meter.is_bursting:
        speed += burst_speed_bonus
    distance = min(distance + speed * delta, target_distance)
    if hud:
        hud.set_distance(distance, target_distance)
    if spawner:
        spawner.poll(distance)
    if distance >= target_distance:
        is_running = false
        stage_completed.emit()

func _process(delta: float) -> void:
    advance_distance(delta)
    if tunnel and player:
        tunnel.set_twist_from_lane(player.lane_index)

func _spawn_obstacle(definition: Dictionary) -> void:
    var obstacle := OBSTACLE_SCENE.instantiate() as RunnerObstacle
    var lane := int(definition.get("lane", 1))
    var lane_x := player.lane_positions[lane]
    obstacle.configure(definition, lane_x, -40.0)
    obstacle_root.add_child(obstacle)

func _on_player_area_entered(area: Area2D) -> void:
    if area is RunnerObstacle:
        var obstacle := area as RunnerObstacle
        if obstacle.is_collectible:
            player.collect_desire(obstacle.desire_value)
            obstacle.queue_free()
            return
        if meter.is_bursting and obstacle.kind in ["desk", "falling_tile"]:
            obstacle.queue_free()
            return
        player.apply_hit(obstacle.damage)
        obstacle.queue_free()
```

- [ ] **Step 4: Create runner stage scene**

Create `scenes/runner/RunnerStage.tscn`:

```ini
[gd_scene load_steps=8 format=3 uid="uid://runner_stage_scene"]

[ext_resource type="Script" path="res://scripts/runner/runner_stage.gd" id="1"]
[ext_resource type="Script" path="res://scripts/runner/lane_tunnel_view.gd" id="2"]
[ext_resource type="PackedScene" path="res://scenes/runner/RunnerPlayer.tscn" id="3"]
[ext_resource type="Script" path="res://scripts/runner/obstacle_spawner.gd" id="4"]
[ext_resource type="Script" path="res://scripts/core/desire_meter.gd" id="5"]
[ext_resource type="PackedScene" path="res://scenes/ui/HUD.tscn" id="6"]

[node name="RunnerStage" type="Node2D"]
script = ExtResource("1")

[node name="LaneTunnelView" type="Node2D" parent="."]
unique_name_in_owner = true
position = Vector2(640, 0)
script = ExtResource("2")

[node name="ObstacleRoot" type="Node2D" parent="."]
unique_name_in_owner = true
position = Vector2(640, 0)

[node name="RunnerPlayer" parent="." instance=ExtResource("3")]
unique_name_in_owner = true
position = Vector2(640, 0)

[node name="ObstacleSpawner" type="Node" parent="."]
unique_name_in_owner = true
script = ExtResource("4")

[node name="DesireMeter" type="Node" parent="."]
unique_name_in_owner = true
script = ExtResource("5")

[node name="HUD" parent="." instance=ExtResource("6")]
unique_name_in_owner = true
```

- [ ] **Step 5: Run runner stage test**

Run:

```powershell
godot --headless --path . --script res://scripts/tests/test_runner_stage.gd
```

Expected: `test_runner_stage passed`

- [ ] **Step 6: Commit runner stage**

Run:

```powershell
git add scripts/runner/runner_stage.gd scripts/tests/test_runner_stage.gd scenes/runner/RunnerStage.tscn
git commit -m "feat: add runner stage flow"
```

Expected: commit succeeds.

### Task 7: Cutscenes and Game Root

**Files:**
- Create: `scripts/core/cutscene_player.gd`
- Create: `scripts/core/game_root.gd`
- Create: `scripts/tests/test_game_root.gd`
- Create: `scenes/cutscenes/CutscenePlayer.tscn`
- Create: `scenes/main/GameRoot.tscn`

- [ ] **Step 1: Write failing game root test**

Create `scripts/tests/test_game_root.gd`:

```gdscript
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
    var game := load("res://scripts/core/game_root.gd").new()
    root.add_child(game)
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
    print("test_game_root passed")
    quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
godot --headless --path . --script res://scripts/tests/test_game_root.gd
```

Expected: FAIL because `game_root.gd` does not exist.

- [ ] **Step 3: Implement cutscene player**

Create `scripts/core/cutscene_player.gd`:

```gdscript
class_name CutscenePlayer
extends Control

signal completed

@export var lines: PackedStringArray = PackedStringArray()

var index: int = 0

@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel

func _ready() -> void:
    show_line()

func configure(title: String, new_lines: PackedStringArray) -> void:
    lines = new_lines
    index = 0
    if is_node_ready():
        title_label.text = title
        show_line()

func show_line() -> void:
    if not is_node_ready():
        return
    if index >= lines.size():
        completed.emit()
        return
    body_label.text = lines[index]

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("jump") or event.is_action_pressed("attack"):
        index += 1
        show_line()
```

- [ ] **Step 4: Implement game root**

Create `scripts/core/game_root.gd`:

```gdscript
class_name GameRoot
extends Node

const CUTSCENE_SCENE := preload("res://scenes/cutscenes/CutscenePlayer.tscn")
const RUNNER_SCENE := preload("res://scenes/runner/RunnerStage.tscn")
const BOSS_SCENE := preload("res://scenes/boss/BossArena.tscn")

var mode: String = ""
var current_scene: Node = null

@onready var scene_root: Node = %SceneRoot

func _ready() -> void:
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
    var cutscene := CUTSCENE_SCENE.instantiate() as CutscenePlayer
    _swap_scene(cutscene)
    cutscene.configure("종례를 뚫고 집으로", PackedStringArray([
        "시계는 멈춘 것 같다.",
        "종례는 끝나지 않는다.",
        "집에 가고 싶다."
    ]))
    cutscene.completed.connect(start_runner)

func start_runner() -> void:
    mode = "Runner"
    var runner := RUNNER_SCENE.instantiate()
    _swap_scene(runner)
    runner.stage_completed.connect(start_boss)
    runner.player_defeated.connect(start_runner)

func start_boss() -> void:
    mode = "Boss"
    var boss := BOSS_SCENE.instantiate()
    _swap_scene(boss)
    boss.boss_defeated.connect(start_ending)
    boss.player_defeated.connect(start_boss)

func start_ending() -> void:
    mode = "EndingCutscene"
    var cutscene := CUTSCENE_SCENE.instantiate() as CutscenePlayer
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
```

- [ ] **Step 5: Create cutscene scene**

Create `scenes/cutscenes/CutscenePlayer.tscn`:

```ini
[gd_scene load_steps=2 format=3 uid="uid://cutscene_player_scene"]

[ext_resource type="Script" path="res://scripts/core/cutscene_player.gd" id="1"]

[node name="CutscenePlayer" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")

[node name="Backdrop" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.02, 0.025, 0.05, 1)

[node name="TitleLabel" type="Label" parent="."]
unique_name_in_owner = true
layout_mode = 0
offset_left = 80.0
offset_top = 80.0
offset_right = 1200.0
offset_bottom = 140.0
text = "종례를 뚫고 집으로"

[node name="BodyLabel" type="Label" parent="."]
unique_name_in_owner = true
layout_mode = 0
offset_left = 80.0
offset_top = 470.0
offset_right = 1200.0
offset_bottom = 560.0
text = "집에 가고 싶다."
```

- [ ] **Step 6: Create game root scene**

Create `scenes/main/GameRoot.tscn`:

```ini
[gd_scene load_steps=2 format=3 uid="uid://game_root_scene"]

[ext_resource type="Script" path="res://scripts/core/game_root.gd" id="1"]

[node name="GameRoot" type="Node"]
script = ExtResource("1")

[node name="SceneRoot" type="Node" parent="."]
unique_name_in_owner = true
```

- [ ] **Step 7: Run game root test**

Run:

```powershell
godot --headless --path . --script res://scripts/tests/test_game_root.gd
```

Expected: `test_game_root passed`

- [ ] **Step 8: Commit cutscenes and game root**

Run:

```powershell
git add scripts/core/cutscene_player.gd scripts/core/game_root.gd scripts/tests/test_game_root.gd scenes/cutscenes/CutscenePlayer.tscn scenes/main/GameRoot.tscn
git commit -m "feat: add chapter scene flow"
```

Expected: commit succeeds.

### Task 8: Boss Arena

**Files:**
- Create: `scripts/boss/boss_player.gd`
- Create: `scripts/boss/homeroom_boss.gd`
- Create: `scripts/boss/boss_projectile.gd`
- Create: `scripts/boss/boss_arena.gd`
- Create: `scripts/tests/test_boss_arena.gd`
- Create: `scenes/boss/BossPlayer.tscn`
- Create: `scenes/boss/HomeroomBoss.tscn`
- Create: `scenes/boss/BossProjectile.tscn`
- Create: `scenes/boss/BossArena.tscn`

- [ ] **Step 1: Write failing boss arena test**

Create `scripts/tests/test_boss_arena.gd`:

```gdscript
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
    var boss := load("res://scripts/boss/homeroom_boss.gd").new()
    root.add_child(boss)
    boss.max_health = 30
    boss.health = 30

    var defeated := false
    boss.defeated.connect(func() -> void:
        defeated = true
    )

    boss.take_damage(10)
    if not _check(boss.health == 20, "boss takes damage"):
        return
    boss.take_damage(25)
    if not _check(boss.health == 0, "boss health clamps at zero"):
        return
    if not _check(defeated, "boss defeat signal emitted"):
        return

    print("test_boss_arena passed")
    quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
godot --headless --path . --script res://scripts/tests/test_boss_arena.gd
```

Expected: FAIL because `homeroom_boss.gd` does not exist.

- [ ] **Step 3: Implement boss player**

Create `scripts/boss/boss_player.gd`:

```gdscript
class_name BossPlayer
extends CharacterBody2D

signal attacked
signal damaged(health: int)
signal defeated

@export var speed: float = 430.0
@export var jump_velocity: float = -760.0
@export var gravity: float = 2100.0
@export var dash_speed: float = 850.0
@export var dash_seconds: float = 0.14

var health: int = 3
var jump_count: int = 0
var dash_time_left: float = 0.0

func _physics_process(delta: float) -> void:
    var axis := Input.get_axis("move_left", "move_right")
    velocity.x = axis * speed
    if dash_time_left > 0.0:
        dash_time_left -= delta
        velocity.x = sign(velocity.x if velocity.x != 0.0 else 1.0) * dash_speed
    if not is_on_floor():
        velocity.y += gravity * delta
    else:
        jump_count = 0
    if Input.is_action_just_pressed("jump") and jump_count < 2:
        velocity.y = jump_velocity
        jump_count += 1
    if Input.is_action_just_pressed("dash"):
        dash_time_left = dash_seconds
    if Input.is_action_just_pressed("attack"):
        attacked.emit()
    move_and_slide()

func apply_hit(damage: int) -> void:
    health = max(health - damage, 0)
    damaged.emit(health)
    if health == 0:
        defeated.emit()
```

- [ ] **Step 4: Implement homeroom boss**

Create `scripts/boss/homeroom_boss.gd`:

```gdscript
class_name HomeroomBoss
extends Node2D

signal defeated
signal pattern_requested(pattern_name: String)

@export var max_health: int = 100
@export var pattern_seconds: float = 1.6

var health: int = 100
var pattern_index: int = 0
var patterns: PackedStringArray = PackedStringArray(["chalk", "rollbook", "exam_burst", "lecture_wave"])

func _ready() -> void:
    health = max_health

func take_damage(amount: int) -> void:
    health = max(health - amount, 0)
    if health == 0:
        defeated.emit()

func request_next_pattern() -> String:
    var pattern := patterns[pattern_index % patterns.size()]
    pattern_index += 1
    pattern_requested.emit(pattern)
    return pattern
```

- [ ] **Step 5: Implement boss projectile**

Create `scripts/boss/boss_projectile.gd`:

```gdscript
class_name BossProjectile
extends Area2D

@export var velocity: Vector2 = Vector2(-420.0, 0.0)
@export var damage: int = 1

func _process(delta: float) -> void:
    position += velocity * delta
    if position.x < -120.0 or position.x > 1400.0 or position.y < -120.0 or position.y > 840.0:
        queue_free()
```

- [ ] **Step 6: Implement boss arena**

Create `scripts/boss/boss_arena.gd`:

```gdscript
class_name BossArena
extends Node2D

signal boss_defeated
signal player_defeated

const PROJECTILE_SCENE := preload("res://scenes/boss/BossProjectile.tscn")

@onready var player: BossPlayer = %BossPlayer
@onready var boss: HomeroomBoss = %HomeroomBoss
@onready var projectile_root: Node2D = %ProjectileRoot
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
    player.attacked.connect(_on_player_attacked)
    player.defeated.connect(func() -> void:
        player_defeated.emit()
    )
    boss.defeated.connect(func() -> void:
        status_label.text = "교문이 열린다"
        boss_defeated.emit()
    )
    boss.pattern_requested.connect(_spawn_pattern)
    var timer := Timer.new()
    timer.wait_time = boss.pattern_seconds
    timer.autostart = true
    timer.timeout.connect(func() -> void:
        boss.request_next_pattern()
    )
    add_child(timer)

func _on_player_attacked() -> void:
    if player.position.distance_to(boss.position) < 190.0:
        boss.take_damage(10)
        status_label.text = "귀가 본능 공격"

func _spawn_pattern(pattern_name: String) -> void:
    status_label.text = pattern_name
    if pattern_name == "chalk":
        _spawn_projectile(Vector2(1040, 360), Vector2(-520, 0))
    elif pattern_name == "rollbook":
        _spawn_projectile(Vector2(900, 160), Vector2(-120, 420))
    elif pattern_name == "exam_burst":
        _spawn_projectile(Vector2(1040, 280), Vector2(-480, 120))
        _spawn_projectile(Vector2(1040, 420), Vector2(-480, -80))
    elif pattern_name == "lecture_wave":
        _spawn_projectile(Vector2(1040, 530), Vector2(-360, 0))

func _spawn_projectile(start_position: Vector2, projectile_velocity: Vector2) -> void:
    var projectile := PROJECTILE_SCENE.instantiate() as BossProjectile
    projectile.position = start_position
    projectile.velocity = projectile_velocity
    projectile_root.add_child(projectile)
```

- [ ] **Step 7: Create boss scenes**

Create `scenes/boss/BossProjectile.tscn`:

```ini
[gd_scene load_steps=3 format=3 uid="uid://boss_projectile_scene"]

[ext_resource type="Script" path="res://scripts/boss/boss_projectile.gd" id="1"]

[sub_resource type="CircleShape2D" id="CircleShape2D_projectile"]
radius = 18.0

[node name="BossProjectile" type="Area2D"]
script = ExtResource("1")

[node name="Body" type="ColorRect" parent="."]
offset_left = -18.0
offset_top = -18.0
offset_right = 18.0
offset_bottom = 18.0
color = Color(1, 0.92, 0.28, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_projectile")
```

Create `scenes/boss/BossPlayer.tscn`:

```ini
[gd_scene load_steps=3 format=3 uid="uid://boss_player_scene"]

[ext_resource type="Script" path="res://scripts/boss/boss_player.gd" id="1"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_boss_player"]
size = Vector2(56, 92)

[node name="BossPlayer" type="CharacterBody2D"]
script = ExtResource("1")

[node name="Body" type="ColorRect" parent="."]
offset_left = -28.0
offset_top = -92.0
offset_right = 28.0
offset_bottom = 0.0
color = Color(0.2, 0.72, 1, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, -46)
shape = SubResource("RectangleShape2D_boss_player")
```

Create `scenes/boss/HomeroomBoss.tscn`:

```ini
[gd_scene load_steps=2 format=3 uid="uid://homeroom_boss_scene"]

[ext_resource type="Script" path="res://scripts/boss/homeroom_boss.gd" id="1"]

[node name="HomeroomBoss" type="Node2D"]
script = ExtResource("1")

[node name="Body" type="ColorRect" parent="."]
offset_left = -80.0
offset_top = -150.0
offset_right = 80.0
offset_bottom = 0.0
color = Color(0.85, 0.2, 0.28, 1)
```

Create `scenes/boss/BossArena.tscn`:

```ini
[gd_scene load_steps=5 format=3 uid="uid://boss_arena_scene"]

[ext_resource type="Script" path="res://scripts/boss/boss_arena.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/boss/BossPlayer.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/boss/HomeroomBoss.tscn" id="3"]

[node name="BossArena" type="Node2D"]
script = ExtResource("1")

[node name="Backdrop" type="ColorRect" parent="."]
offset_right = 1280.0
offset_bottom = 720.0
color = Color(0.08, 0.06, 0.08, 1)

[node name="Floor" type="StaticBody2D" parent="."]
position = Vector2(640, 640)

[node name="BossPlayer" parent="." instance=ExtResource("2")]
unique_name_in_owner = true
position = Vector2(220, 600)

[node name="HomeroomBoss" parent="." instance=ExtResource("3")]
unique_name_in_owner = true
position = Vector2(980, 600)

[node name="ProjectileRoot" type="Node2D" parent="."]
unique_name_in_owner = true

[node name="StatusLabel" type="Label" parent="."]
unique_name_in_owner = true
offset_left = 40.0
offset_top = 40.0
offset_right = 800.0
offset_bottom = 80.0
text = "담임 선생님: 종례의 수호자"
```

- [ ] **Step 8: Run boss arena test**

Run:

```powershell
godot --headless --path . --script res://scripts/tests/test_boss_arena.gd
```

Expected: `test_boss_arena passed`

- [ ] **Step 9: Commit boss arena**

Run:

```powershell
git add scripts/boss/boss_player.gd scripts/boss/homeroom_boss.gd scripts/boss/boss_projectile.gd scripts/boss/boss_arena.gd scripts/tests/test_boss_arena.gd scenes/boss/BossPlayer.tscn scenes/boss/HomeroomBoss.tscn scenes/boss/BossProjectile.tscn scenes/boss/BossArena.tscn
git commit -m "feat: add homeroom boss fight"
```

Expected: commit succeeds.

### Task 9: Full Chapter Verification and Playability Pass

**Files:**
- Modify: `project.godot`
- Modify: `scenes/runner/RunnerStage.tscn`
- Modify: `scenes/boss/BossArena.tscn`
- Modify: `scripts/runner/runner_stage.gd`
- Modify: `scripts/boss/boss_arena.gd`

- [ ] **Step 1: Run all headless tests**

Run:

```powershell
godot --headless --path . --script res://scripts/tests/test_project_loads.gd
godot --headless --path . --script res://scripts/tests/test_desire_meter.gd
godot --headless --path . --script res://scripts/tests/test_runner_player.gd
godot --headless --path . --script res://scripts/tests/test_obstacle_spawner.gd
godot --headless --path . --script res://scripts/tests/test_runner_stage.gd
godot --headless --path . --script res://scripts/tests/test_game_root.gd
godot --headless --path . --script res://scripts/tests/test_boss_arena.gd
```

Expected: every command prints `passed`.

- [ ] **Step 2: Run project load verification**

Run:

```powershell
godot --headless --path . --quit
```

Expected: Godot exits without parse errors, missing script errors, or scene load errors.

- [ ] **Step 3: Run manual play verification**

Run:

```powershell
godot --path .
```

Expected:

- Intro cutscene appears.
- Pressing `Space` advances intro lines.
- Runner scene starts.
- `A/D`, `Space`, double `Space`, and `S` change player state.
- Obstacles spawn and move toward the player.
- Desire gauge fills when a key item is collected.
- Burst mode changes HUD status and tunnel color.
- Runner completion transitions to boss arena.
- `A/D`, `Space`, `Shift`, and `Z` work in the boss arena.
- Boss uses chalk, rollbook, exam burst, and lecture wave patterns.
- Attacking near the boss defeats it.
- Ending cutscene appears.

- [ ] **Step 4: Fix only verification failures**

When a command reports a specific missing path, parse error, signal connection error, or node path error, patch the smallest matching file. Examples:

```gdscript
@onready var hud: HUD = %HUD
```

Use this node access style only when the target scene marks the child with:

```ini
unique_name_in_owner = true
```

If a scene preload fails, correct the path to a `res://` path that exists in the repository.

- [ ] **Step 5: Commit final playability pass**

Run:

```powershell
git add project.godot scenes scripts
git commit -m "feat: complete playable school chapter slice"
```

Expected: commit succeeds.

## Self-Review

Spec coverage:

- Electron Dash-inspired 2.5D tunnel runner: covered by Tasks 4, 5, and 6.
- School 1챕터 flow from intro to runner to boss to ending: covered by Tasks 7 and 9.
- Jump, double jump, duck, lane movement: covered by Task 3.
- At least five obstacle types and desire item: covered by Task 5.
- Desire gauge and burst mode: covered by Tasks 2 and 6.
- Free-movement boss fight with four patterns: covered by Task 8.
- Godot 4 project structure and verification: covered by Tasks 1 and 9.

Placeholder scan:

- No empty placeholder language is present.

Type consistency:

- `DesireMeter`, `RunnerPlayer`, `LaneTunnelView`, `ObstacleSpawner`, `RunnerObstacle`, `RunnerStage`, `HUD`, `GameRoot`, `CutscenePlayer`, `BossPlayer`, `HomeroomBoss`, `BossProjectile`, and `BossArena` are defined before they are referenced by scenes or later tasks.
- Signal names match across producers and consumers: `changed`, `burst_started`, `burst_ended`, `stage_completed`, `player_defeated`, `boss_defeated`, `defeated`, `pattern_requested`, `spawn_requested`.
