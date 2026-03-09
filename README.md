# SimBuddy

> iOS Developer Menubar Utility for macOS

[![macOS 15.0+](https://img.shields.io/badge/macOS-15.0%2B-black?logo=apple)](https://simbuddy.intmain.co.kr)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

SimBuddy는 iOS 개발자를 위한 macOS 메뉴바 유틸리티입니다. Xcode와 터미널을 오가며 반복하던 시뮬레이터 경로 탐색과 정리 작업을 메뉴바 클릭 한 번으로 줄여줍니다.

**[Website](https://simbuddy.intmain.co.kr)** · **[Download](https://github.com/intmain/SimBuddy/releases/latest)**

---

## Features

### Simulator List
메뉴바 아이콘 클릭 시 전체 시뮬레이터 목록을 확인할 수 있습니다. Booted 시뮬레이터는 상단에, Shutdown 시뮬레이터는 서브메뉴에 정리됩니다.

### Sandbox Explorer
시뮬레이터에 마우스를 올리면 설치된 앱 목록이 서브메뉴로 표시됩니다.
- **클릭**: 앱의 샌드박스 디렉토리를 Finder에서 열기
- **⌥ Option + 클릭**: 샌드박스 경로를 클립보드에 복사

### Storage Manager
별도 윈도우에서 시뮬레이터 관련 디스크 공간을 관리합니다.
- **Dead Folder**: 불필요한 캐시/orphan 폴더 스캔 및 정리
- **미사용 시뮬레이터**: 30일 이상 미사용 시뮬레이터 식별 및 정리 추천
- **앱별 용량**: 전체 시뮬레이터의 앱별 샌드박스 용량 확인

모든 삭제는 **휴지통으로 이동**합니다 (영구 삭제 아님).

### Provisioning Profiles
한 번의 클릭으로 `~/Library/MobileDevice/Provisioning Profiles/` 디렉토리를 Finder에서 엽니다.

---

## Install

### Download
[Releases](https://github.com/intmain/SimBuddy/releases/latest) 페이지에서 DMG를 다운로드하고, SimBuddy.app을 Applications 폴더로 드래그하세요.

### Build from source
```bash
git clone https://github.com/intmain/SimBuddy.git
cd SimBuddy
xcodebuild -project SimBuddy.xcodeproj -scheme SimBuddy -configuration Release build
```

---

## Requirements

- macOS 15.0 (Sequoia) 이상
- Xcode Command Line Tools (`xcrun simctl` 사용)

---

## Tech Stack

| 항목 | 내용 |
|------|------|
| Language | Swift 6.0 |
| UI | SwiftUI + AppKit |
| Architecture | MVVM |
| Menu | MenuBarExtra (native NSMenu) |
| Simulator Data | `xcrun simctl list --json` |
| Code Signing | Developer ID + Notarization |

---

## Project Structure

```
SimBuddy/
├── SimBuddyApp.swift          # App entry point (MenuBarExtra)
├── Models/
│   ├── Simulator.swift         # SimulatorDevice, SimctlListResponse
│   └── SimulatorApp.swift      # SimulatorApp model
├── Services/
│   ├── SimulatorService.swift  # xcrun simctl parsing
│   ├── SandboxService.swift    # Sandbox directory browsing
│   └── StorageService.swift    # Storage calculation & cleanup
├── ViewModels/
│   ├── MenuBarViewModel.swift
│   └── StorageManagerViewModel.swift
└── Views/
    ├── MenuBarView.swift       # Main menu content
    ├── StorageManagerView.swift
    ├── DeadFolderTab.swift
    ├── UnusedSimulatorsTab.swift
    └── AppStorageTab.swift
```

---

## License

MIT
