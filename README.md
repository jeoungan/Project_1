# 집에 가고 싶다

Godot 4.6 기반 3D 터널 러너 프로토타입입니다. 이전 학교 챕터 구조를 버리고, `Electron Dash`처럼 원형 터널을 달리며 구멍과 레이저를 피하는 게임으로 갈아엎었습니다.

## 실행

```powershell
& 'C:\Users\jeoun\Downloads\Godot_v4.6.2-stable_win64.exe' --path 'C:\Users\jeoun\OneDrive\바탕 화면\집에 가고 싶다'
```

## 조작

- `A/D` 또는 `Left/Right`: 터널 둘레를 좌우로 회전
- `Space` 또는 `W`: 점프
- `S` 또는 `Down`: 레이저 회피용 숙이기
- `R`: 게임 오버 후 재시작

## 현재 구현

- 원형 터널 레인 12개
- 자동 전진과 점점 빨라지는 속도
- 빈 바닥 타일 충돌
- 레이저 장애물과 숙이기 회피
- 점프 기반 구멍 회피
- 점수, 속도, 게임 오버 UI
- Godot headless 테스트

## 테스트

```powershell
& 'C:\Users\jeoun\Downloads\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/tests/test_electron_dash_rules.gd
& 'C:\Users\jeoun\Downloads\Godot_v4.6.2-stable_win64_console.exe' --headless --path . --script res://scripts/tests/test_scene_loads.gd
```
