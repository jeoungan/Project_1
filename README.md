# 집에 가고 싶다

Godot 4.6 기반 3D 튜브 러너 프로토타입입니다. 현재 버전은 `Electron Dash`처럼 캐릭터는 화면 아래에 고정되고, `A/D` 입력으로 5개 패널 바닥 터널이 회전하며 진행합니다.

## 실행

폴더 안의 `집에 가고 싶다 실행.lnk`를 더블클릭하면 바로 실행됩니다. 바로가기가 막히는 환경에서는 `집에 가고 싶다 실행.cmd`를 더블클릭해도 됩니다.

## 조작

- `A/D` 또는 `Left/Right`: 바닥 회전
- `W` 또는 `Up`: 점프
- `R`: 즉시 재시작

## 현재 구현

- 속도 12에서 시작해 점점 빨라지는 진행
- 매번 새 seed로 생성되는 맵
- 5개 충돌 패널을 유지한 회전 튜브 이동
- 일반 길은 이어진 타일로 유지
- 한 번의 점프로 넘기 어려운 긴 구덩이 장애물
- 진한 남색 일반 타일과 조금 밝은 남색 불안정 타일
- 단순한 네모 플레이어 캐릭터
- 생존 시간 기반 점수와 최고 기록 UI
- 충돌 후 `R` 입력까지 정지
- 더블클릭 실행 바로가기
- Godot headless 테스트

## 장애물 색 의미

- 진한 남색 패널: 일반 고정 타일입니다.
- 조금 밝은 남색 패널: 불안정 패널입니다. 밟으면 실패하므로 점프하거나 다른 레인으로 피해야 합니다.
- 길이 끊긴 검은 구간: 레인을 돌려 피해야 하는 긴 구덩이입니다. 한 번의 점프로 넘기 어렵게 여러 줄 연속으로 끊깁니다.

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
