# 집에 가고 싶다

Godot 4.6 기반 3D 튜브 러너 프로토타입입니다. 현재 버전은 `Electron Dash`처럼 캐릭터는 화면 아래에 고정되고, `A/D` 입력으로 5개 패널 바닥 터널이 회전하며 진행합니다.

## 실행

폴더 안의 `집에 가고 싶다 실행.lnk`를 더블클릭하면 바로 실행됩니다. 바로가기가 막히는 환경에서는 `집에 가고 싶다 실행.cmd`를 더블클릭해도 됩니다.

## 조작

- `A/D` 또는 `Left/Right`: 바닥 회전
- `W` 또는 `Up`: 점프
- `R`: 즉시 재시작

## 현재 구현

- 5개 충돌 패널을 유지한 회전 튜브 이동
- 검은 우주 배경, 네온 튜브 그리드, 더 밝은 패널 발광
- 파란 우주인 실루엣, 주황 바이저, 위치 파악용 그림자
- 빈 바닥, 불안정 패널, 빨간 레이저 빔
- 하트 픽업, 추가 생명, 짧은 무적 리스폰
- 생존 시간 기반 점수와 최고 기록 UI
- 충돌 후 `R` 입력까지 정지
- 더블클릭 실행 바로가기
- Godot headless 테스트

## 장애물 색 의미

- 빨간색 바: 레이저입니다. 닿으면 실패하므로 레인을 돌려 피해야 합니다.
- 노란색 패널: 불안정 패널입니다. 밟으면 무너지므로 점프하거나 다른 레인으로 피해야 합니다.
- 길이 끊긴 검은 구간: 점프로 넘어가야 하는 구멍입니다.

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
