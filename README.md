# 집에 가고 싶다

Godot 4.6 기반 3D 러너 프로토타입입니다. 현재 버전은 `Electron Dash`처럼 캐릭터는 화면 아래에 고정되고, `A/D` 입력으로 바닥 터널이 회전하며 진행합니다.

## 실행

폴더 안의 `집에 가고 싶다 실행.lnk`를 더블클릭하면 바로 실행됩니다. 바로가기가 막히는 환경에서는 `집에 가고 싶다 실행.cmd`를 더블클릭해도 됩니다.

## 조작

- `A/D` 또는 `Left/Right`: 바닥 회전
- `Space` 또는 `W`: 점프
- `S` 또는 `Down`: 레이저 회피용 숙이기
- `R`: 즉시 재시작

## 현재 구현

- 캐릭터 고정, 바닥 회전 방식의 레인 이동
- 속 울렁임을 줄인 하단 반원 바닥 패널
- 자동 전진, 점수, 속도 UI
- 빈 바닥과 레이저 장애물
- 충돌 후 1.1초 자동 재시작
- 더블클릭 실행 바로가기
- Godot headless 테스트

## 테스트

```powershell
$godot = 'C:\Users\jeoun\Downloads\Godot_v4.6.2-stable_win64_console.exe'
$tests = @(
  'res://scripts/tests/test_electron_dash_rules.gd',
  'res://scripts/tests/test_scene_loads.gd',
  'res://scripts/tests/test_project_settings.gd',
  'res://scripts/tests/test_electron_dash_game_behavior.gd',
  'res://scripts/tests/test_launcher_exists.gd'
)
foreach ($test in $tests) {
  & $godot --headless --path . --script $test
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```
