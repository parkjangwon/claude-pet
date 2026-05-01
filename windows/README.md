# ClaudePet for Windows

Windows용 ClaudePet 포팅 버전입니다. 원본 macOS SwiftUI 앱은 그대로 유지하고, Windows에서는 투명 항상위 창과 트레이를 다루기 쉬운 Electron 런타임으로 구현했습니다.

## 실행

```bash
cd windows
npm install
npm start
```

## 빌드

```bash
cd windows
npm install
npm run dist
```

빌드 결과물은 `windows/dist` 아래에 생성됩니다.

## Windows 대체 인터랙션

- 클릭: 좋아하기 / 하트
- 우클릭: HUD 메뉴 열기
- 더블클릭 또는 `Shift+클릭`: macOS Force Touch 대체 동작. 누른 방향의 반대로 놀라서 이동합니다.
- 전역 타이핑 카운터: `uiohook-napi`가 설치되면 네이티브 훅으로 동작합니다. 네이티브 훅 로딩에 실패하면 앱에 포커스가 있을 때만 카운트합니다.
- Claude 작업 감지: Windows의 `Claude.exe` 프로세스 CPU 사용량을 PowerShell로 폴링합니다.

## 아직 macOS와 다른 점

- Force Touch, macOS 햅틱, Apple Silicon 내장 가속도계 충격 감지는 Windows에서 구조적으로 제외했습니다.
- Sparkle 업데이트는 macOS 전용이라 Windows 빌드에서는 빠졌습니다. 배포 단계에서는 `electron-builder` 업데이트 채널을 붙이면 됩니다.
- Windows 전역 키 감지를 더 정교하게 하려면 `uiohook-napi` 같은 네이티브 훅 라이브러리로 교체하는 것이 다음 단계입니다.
