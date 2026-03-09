#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# SimBuddy Release Script
# Usage: ./scripts/release.sh <version> [--yes]
# Example: ./scripts/release.sh 1.0.0
#          ./scripts/release.sh 1.0.0 --yes
# ─────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$PROJECT_DIR/SimBuddy.xcodeproj"
SCHEME="SimBuddy"
NOTARY_PROFILE="notarytool"

# ─── 인자 파싱 ───
VERSION=""
AUTO_YES=false

for arg in "$@"; do
    case "$arg" in
        --yes|-y) AUTO_YES=true ;;
        -*) echo "Unknown option: $arg"; exit 1 ;;
        *) VERSION="$arg" ;;
    esac
done

if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version> [--yes]"
    echo "  --yes, -y  모든 확인을 자동 승인"
    echo ""
    echo "Example: $0 1.0.0"
    exit 1
fi

confirm() {
    if [[ "$AUTO_YES" == true ]]; then return 0; fi
    read -p "$1 (y/N) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

TAG="v$VERSION"
DMG_NAME="SimBuddy-${VERSION}.dmg"
BUILD_DIR="/tmp/simbuddy-release"
ARCHIVE_PATH="$BUILD_DIR/SimBuddy.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
DMG_STAGING="$BUILD_DIR/dmg-staging"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

echo "========================================"
echo "  SimBuddy Release $VERSION"
echo "========================================"

# ─── 1. 사전 확인 ───
echo ""
echo "[1/7] 사전 확인..."

cd "$PROJECT_DIR"

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "  ⚠ 커밋되지 않은 변경사항이 있습니다."
    confirm "  계속하시겠습니까?" || exit 1
fi

echo "  ✓ Working tree 확인 완료"

# ─── 2. Clean & Archive ───
echo ""
echo "[2/7] Archive 빌드..."

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$(date +%Y%m%d)" \
    2>&1 | tail -3

echo "  ✓ Archive 완료"

# ─── 3. Export ───
echo ""
echo "[3/7] Export..."

mkdir -p "$EXPORT_DIR"
ditto "$ARCHIVE_PATH/Products/Applications/SimBuddy.app" "$EXPORT_DIR/SimBuddy.app"

if codesign --verify --deep "$EXPORT_DIR/SimBuddy.app" 2>/dev/null; then
    echo "  ✓ Export 완료 (서명 유효)"
else
    echo "  ⚠ 서명 검증 실패 (Developer ID 인증서 확인 필요)"
    confirm "  서명 없이 계속하시겠습니까?" || exit 1
fi

# ─── 4. DMG 생성 ───
echo ""
echo "[4/7] DMG 생성..."

rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
ditto "$EXPORT_DIR/SimBuddy.app" "$DMG_STAGING/SimBuddy.app"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
    -volname "SimBuddy" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_PATH" \
    2>&1 | tail -1

echo "  ✓ DMG 생성: $DMG_PATH"

# ─── 5. 공증 (Notarization) ───
echo ""
echo "[5/7] 공증 (Notarization)..."

if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" &>/dev/null; then
    echo "  공증 제출 중..."
    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait \
        2>&1 | grep -E "status|id"

    echo "  Stapling..."
    xcrun stapler staple "$DMG_PATH"
    echo "  ✓ 공증 완료"
else
    echo "  ⚠ notarytool 키체인 프로필 없음 - 공증 생략"
    echo "  설정하려면: xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id <email> --team-id 8LHHKYA787"
fi

# ─── 6. /Applications 설치 ───
echo ""
echo "[6/7] 로컬 앱 설치..."

if confirm "  /Applications/SimBuddy.app에 설치하시겠습니까?"; then
    killall SimBuddy 2>/dev/null || true
    sleep 1
    rm -rf /Applications/SimBuddy.app
    ditto "$EXPORT_DIR/SimBuddy.app" /Applications/SimBuddy.app
    open -a /Applications/SimBuddy.app
    echo "  ✓ 설치 완료"
else
    echo "  건너뜀"
fi

# ─── 7. 완료 ───
echo ""
echo "[7/7] 정리..."
echo ""
echo "========================================"
echo "  SimBuddy $VERSION 릴리스 완료!"
echo "========================================"
echo ""
echo "  DMG: $DMG_PATH"
echo ""
echo "  남은 작업:"
echo "  1. DMG를 팀에 공유하거나 GitHub Release에 업로드"
echo ""
