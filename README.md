<p align="center">
  <img src=".github/assets/app-icon.png" width="128" height="128" alt="Claude Watchdog Icon">
</p>

<h1 align="center">Claude Watchdog</h1>

<p align="center">
  <strong>Claude Code 사용량을 macOS 메뉴 바에서 실시간 모니터링</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014.0%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/arch-Universal%20(ARM%20%2B%20Intel)-green" alt="Architecture">
  <img src="https://img.shields.io/badge/swift-5.0-orange" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-lightgrey" alt="License">
</p>

---

## Overview

Claude Watchdog는 [Claude Code](https://claude.ai/claude-code) 사용량을 macOS 메뉴 바에 퍼센티지로 표시하는 네이티브 앱입니다. Claude Code의 Keychain 크리덴셜을 자동으로 감지하여 별도 설정 없이 바로 사용할 수 있습니다.

### Features

- **메뉴 바 실시간 표시** — 세션(5시간) 사용량을 아이콘으로 즉시 확인
- **3가지 아이콘 스타일** — 퍼센티지(%), 프로그레스 바, 배터리
- **사용량 색상 코딩** — 초록(~74%) → 노랑(75~89%) → 주황(90~94%) → 빨강(95%~)
- **상세 팝오버** — 세션/주간/Opus/Sonnet 모델별 사용량 + 리셋 시간
- **macOS 위젯** — Small/Medium 위젯으로 데스크톱에서 확인
- **알림** — 75%, 90%, 95% 임계값 도달 시 macOS 시스템 알림
- **로그인 시 자동 실행** — 시스템 설정과 연동
- **Keychain 자동 감지** — Claude Code 인증 정보 자동 로드 (별도 설정 불필요)

## Requirements

- macOS 14.0 (Sonoma) 이상
- [Claude Code](https://claude.ai/claude-code)가 설치되고 로그인된 상태

## Installation

### DMG (권장)

[Releases](https://github.com/dandacompany/claude-watchdog/releases) 페이지에서 최신 DMG를 다운로드하세요.

1. `Claude-Watchdog-x.x.x-Universal.dmg`를 열고
2. `Claude Watchdog.app`을 `Applications`로 드래그
3. 앱을 실행하면 메뉴 바에 사용량이 표시됩니다

> Apple Developer ID로 서명 및 공증(Notarized)되어 있어 Gatekeeper 경고 없이 설치됩니다.

### Build from Source

```bash
# 1. 클론
git clone https://github.com/dandacompany/claude-watchdog.git
cd claude-watchdog

# 2. XcodeGen으로 프로젝트 생성
brew install xcodegen
xcodegen generate

# 3. 빌드 (Universal Binary)
xcodebuild -project ClaudeWatchdog.xcodeproj \
  -scheme ClaudeWatchdog \
  -configuration Release \
  -derivedDataPath build \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  build

# 4. 앱 실행
open build/Build/Products/Release/Claude\ Watchdog.app
```

## How It Works

```
┌──────────────┐     Keychain      ┌───────────────────┐
│ Claude Code  │ ──── OAuth ────▶  │  macOS Keychain    │
│  (Terminal)  │     Token         │  (자동 저장)       │
└──────────────┘                   └────────┬──────────┘
                                            │ 자동 감지
                                   ┌────────▼──────────┐
                                   │  Claude Watchdog   │
                                   │  (Menu Bar App)    │
                                   └────────┬──────────┘
                                            │ API 호출
                                   ┌────────▼──────────┐
                                   │  Claude API        │
                                   │  /api/oauth/usage  │
                                   └───────────────────┘
```

1. Claude Code가 로그인 시 OAuth 토큰을 macOS Keychain에 저장합니다
2. Claude Watchdog이 Keychain에서 토큰을 자동으로 읽습니다
3. 주기적으로 Claude API를 호출하여 사용량을 가져옵니다
4. 메뉴 바 아이콘과 위젯에 실시간 반영합니다

## Project Structure

```
claude-watchdog/
├── project.yml                  # XcodeGen 프로젝트 설정
├── ClaudeWatchdog/              # 메인 앱
│   ├── App/                     # 앱 진입점, AppDelegate
│   ├── MenuBar/                 # 메뉴 바 아이콘 렌더링 & 관리
│   ├── Models/                  # ClaudeUsage, AppSettings
│   ├── Services/                # API, Keychain, 알림, 공유 저장소
│   └── Views/                   # 팝오버 UI
└── ClaudeWatchdogWidget/        # macOS 위젯 (Small, Medium)
```

## Configuration

팝오버에서 모든 설정을 변경할 수 있습니다:

| 설정 | 옵션 | 기본값 |
|------|------|--------|
| 아이콘 스타일 | %, Bar, Battery | % |
| 갱신 주기 | 15초, 30초, 60초, 5분 | 30초 |
| 알림 (75%) | On/Off | On |
| 알림 (90%) | On/Off | On |
| 알림 (95%) | On/Off | On |
| 로그인 시 자동 실행 | On/Off | Off |

## Tech Stack

- **Language**: Swift 5.0
- **UI**: SwiftUI + AppKit (NSStatusItem, NSPopover)
- **Widget**: WidgetKit
- **Auth**: macOS Keychain (Security framework)
- **Build**: XcodeGen
- **Target**: macOS 14.0+ (Universal Binary: ARM64 + x86_64)

## License

MIT License. See [LICENSE](LICENSE) for details.

## Credits

Inspired by [Claude Usage Tracker](https://github.com/hamed-elfayome/Claude-Usage-Tracker).
