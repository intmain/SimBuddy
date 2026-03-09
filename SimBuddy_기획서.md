# SimBuddy 기획서 v1.0

> iOS Developer Menubar Utility — 작성일: 2026.03.09

---

## 1. 제품 개요

SimBuddy는 iOS 개발자를 위한 macOS 메뉴바 유틸리티입니다.
iOS 시뮬레이터의 앱 샌드박스 디렉토리 탐색, 용량 관리, 프로비저닝 프로파일 접근을 메뉴바에서 빠르게 처리할 수 있도록 돕습니다.

Xcode와 터미널을 오가며 반복적으로 수행하던 경로 탐색·정리 작업을 메뉴바 클릭 한 번으로 줄이는 것이 핵심 목표입니다.

---

## 2. 타겟 사용자

- 주 타겟: iOS 앱 개발자 (개인, 팀 내 배포 환경)
- macOS 15.7 (Sequoia) 이상 사용자
- Xcode 시뮬레이터를 활발히 사용하는 개발자
- 추후 확장: 외부 배포 (Mac App Store / Notarization)

---

## 3. 기술 스택 및 환경

| 항목 | 내용 |
|------|------|
| 언어 | Swift |
| UI 프레임워크 | SwiftUI + AppKit |
| 최소 지원 OS | macOS 15.7 (Sequoia) 이상 |
| 배포 방식 (현재) | Ad-hoc / 사내 배포 |
| 배포 방식 (추후) | Mac App Store 또는 Notarized 공개 배포 |
| 시뮬레이터 데이터 접근 | xcrun simctl, 파일시스템 직접 접근 |
| 주요 루트 경로 | `~/Library/Developer/CoreSimulator/` |

---

## 4. 기능 명세

### 4-1. 메뉴바 구조

앱은 macOS 메뉴바(상태 표시줄)에 아이콘으로 상주합니다. 아이콘 클릭 시 드롭다운 메뉴가 표시됩니다.

```
● iPhone 16 Pro — iOS 18.2    ▶  (Booted)
● iPhone 15 — iOS 17.5        ▶  (Booted)
─────────────────────────────
○ Shutdown Simulators         ▶  (접기/펼치기)
─────────────────────────────
🧹 Storage Manager
📁 Provisioning Profiles
─────────────────────────────
Quit SimBuddy
```

### 4-2. 시뮬레이터 탐색 기능

#### 시뮬레이터 목록

- `xcrun simctl list --json` 으로 전체 시뮬레이터 목록 파싱
- **Booted** 상태 시뮬레이터를 메뉴 상단에 분리 표시
- **Shutdown** 시뮬레이터는 접을 수 있는 서브섹션으로 표시
- 각 항목에 기기명 + iOS 버전 표시 (예: `iPhone 16 Pro — iOS 18.2`)

#### 앱 목록 서브메뉴

- 시뮬레이터 항목에 마우스를 올리면 서브메뉴로 설치된 앱 목록 표시
- 앱 Display Name 기준으로 표시 (Info.plist의 `CFBundleDisplayName` 또는 `CFBundleName` 파싱)

#### Finder 이동 및 경로 복사

| 동작 | 결과 |
|------|------|
| 앱 항목 **클릭** | 해당 앱의 샌드박스 루트 디렉토리를 Finder로 열기 |
| **Option(⌥) + 클릭** | 해당 앱의 샌드박스 루트 경로를 클립보드에 복사 (Finder 열지 않음) |

샌드박스 루트 경로 패턴:
```
~/Library/Developer/CoreSimulator/Devices/{UUID}/data/Containers/Data/Application/{AppUUID}/
```

---

### 4-3. Storage Manager (용량 관리 윈도우)

메뉴에서 `🧹 Storage Manager` 클릭 시 별도 윈도우가 열립니다. 윈도우는 세 개의 탭으로 구성됩니다.

#### Tab 1 — Dead Folder

- 스캔 대상: `~/Library/Developer/CoreSimulator/Caches/` 및 알려진 orphan 경로
- 각 항목의 용량 계산 후 표시
- 선택 삭제 또는 전체 삭제 버튼 제공
- 삭제 전 확인 다이얼로그 표시

#### Tab 2 — 미사용 시뮬레이터

- 전체 시뮬레이터 목록을 용량과 함께 표시
- `lastBootedAt` 기준 마지막 사용 일시 표시 — 오래된 항목 시각적 강조
- Shutdown 상태이며 일정 기간 미사용 시 **"정리 추천"** 배지 표시
- 개별 선택 삭제 또는 "추천 항목 전체 삭제" 버튼 제공
- 삭제 전 확인 다이얼로그 표시

#### Tab 3 — 앱별 샌드박스 용량

- 현재 설치된 모든 시뮬레이터의 앱별 샌드박스 용량 집계
- 시뮬레이터 기기명 + 앱 이름 + 용량 목록 표시
- 용량 내림차순 정렬
- Finder로 바로 이동 버튼 제공

#### 공통 UX

- 윈도우 오픈 시 백그라운드에서 용량 스캔 시작 → 프로그레스 표시
- "새로고침" 버튼으로 재스캔 가능

---

### 4-4. 프로비저닝 프로파일

- 메뉴 항목: `📁 Provisioning Profiles`
- 클릭 시 `~/Library/MobileDevice/Provisioning Profiles/` 를 Finder로 열기

---

## 5. UX 세부 사항

| 항목 | 동작 |
|------|------|
| 메뉴바 아이콘 | SF Symbol 또는 커스텀 아이콘 (망치 + 시뮬레이터 조합 고려) |
| 앱 목록 로딩 | 메뉴 오픈 시 `xcrun simctl` 비동기 실행, 로딩 중 스피너 표시 |
| Option 클릭 힌트 | 메뉴 하단에 단축키 안내 표시 (`⌥ click to copy path`) |
| 시뮬레이터 없을 때 | "No Simulators Found" 비활성화 항목 표시 |
| 앱 없을 때 | "No Apps Installed" 비활성화 항목 표시 |
| Login Item | 시스템 시작 시 자동 실행 옵션 (설정에서 ON/OFF) |

---

## 6. 데이터 소스 및 주요 경로

| 데이터 | 소스 / 경로 |
|--------|------------|
| 시뮬레이터 목록 | `xcrun simctl list --json` |
| 앱 샌드박스 루트 | `~/Library/Developer/CoreSimulator/Devices/{UUID}/data/Containers/Data/Application/` |
| 앱 Display Name | 앱 번들 내 `Info.plist` (`CFBundleDisplayName`, `CFBundleName`) |
| Dead/캐시 폴더 | `~/Library/Developer/CoreSimulator/Caches/` |
| 시뮬레이터 메타데이터 | `device.plist` (`lastBootedAt` 등) |
| 프로비저닝 프로파일 | `~/Library/MobileDevice/Provisioning Profiles/` |

---

## 7. 권한 및 보안

- 샌드박스 환경 외부 파일 접근 필요 → App Sandbox 비활성화 또는 entitlement 설정 필요
- 파일 삭제 기능 포함 → 삭제 전 반드시 확인 다이얼로그 표출
- Mac App Store 배포 전환 시 Sandbox 정책 재검토 필요
- Hardened Runtime 적용 (추후 공개 배포 대비)

---

## 8. 개발 로드맵

| 단계 | 범위 | 목표 |
|------|------|------|
| **Phase 1 (MVP)** | 메뉴바 앱 기반, 시뮬레이터 목록 + 앱 Finder 이동 + Option 클릭 경로 복사 + 프로비저닝 Finder 이동 | 내부 사용 가능한 첫 빌드 |
| **Phase 2** | Storage Manager 윈도우 (Dead 폴더, 미사용 시뮬레이터, 앱 용량 탭) | 용량 관리 기능 완성 |
| **Phase 3** | 안정화, UI polish, Login Item 설정, Ad-hoc 배포 세팅 | 팀 내 배포 |
| **Phase 4** | Notarization, Mac App Store 심사 대비 Sandbox 검토 | 외부 배포 준비 |

---

## 9. 추후 결정 필요 사항

- 앱 이름 확정 (현재 가칭: **SimBuddy**)
- 메뉴바 아이콘 디자인
- 미사용 시뮬레이터 기준 일수 (기본값 30일 고정 vs 사용자 설정 가능)
- Storage Manager 윈도우 레이아웃 (탭 vs 사이드바 네비게이션)
- Phase 4 App Store 배포 여부 및 유료/무료 정책
