#!/usr/bin/env bash
# Standard Anini release command:
#   ./scripts/release.sh [platform] [mode] [version option] [other options]
#
# Platforms: android, ios, macos, web, all
# Modes: beta (default), store, direct
# Version options: --patch (default), --build, --minor, --major, --no-increment

set -euo pipefail

APP_NAME="AniniTools"
APP_RELATIVE_DIR="."
SUPPORTED_PLATFORMS="android ios"
ANDROID_KEY_PROPERTIES="android/key.properties"
DART_DEFINE_FILE=""
PREPARE_RUST=false
VERIFY_BACKEND=false
ADS_GUARD_FILE=""
LEGACY_MACOS_DEPLOY_SCRIPT=""

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$PROJECT_ROOT/$APP_RELATIVE_DIR"
cd "$PROJECT_ROOT"

if command -v rbenv >/dev/null 2>&1; then
  export RBENV_VERSION="$(cat "$PROJECT_ROOT/.ruby-version")"
  export PATH="$(rbenv root)/shims:$PATH"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${CYAN}[$APP_NAME]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

show_usage() {
  cat <<EOF
Usage: ./scripts/release.sh [platform] [mode] [options]

Platforms: $SUPPORTED_PLATFORMS, all
Modes:
  beta    Upload to TestFlight and Play Internal Testing. This is the default.
  store   Upload to App Store Connect and the Play production track as a draft.
  direct  Build store artifacts without uploading.

Version options:
  --patch          Increment patch version and build number. This is the default.
  --build          Increment only the build number.
  --minor          Increment minor version and build number.
  --major          Increment major version and build number.
  --no-increment   Keep the current version and build number.

Other options:
  --skip-clean
  --skip-rust
  --skip-verify
  --cleanup
  -h, --help

Examples:
  ./scripts/release.sh
  ./scripts/release.sh ios
  ./scripts/release.sh android store
  ./scripts/release.sh all beta --no-increment
  ./scripts/release.sh all direct --build
EOF
}

supports_platform() {
  [[ " $SUPPORTED_PLATFORMS " == *" $1 "* ]]
}

platform_selected() {
  [ "$PLATFORM" = "all" ] || [ "$PLATFORM" = "$1" ]
}

check_file() {
  [ -f "$1" ] || fail "$2 not found: $1"
}

PLATFORM=""
MODE=""
VERSION_BUMP="patch"
NO_INCREMENT=false
SKIP_CLEAN=false
SKIP_RUST=false
SKIP_VERIFY=false
CLEAN_AFTER_RELEASE=false

for arg in "$@"; do
  case "$arg" in
    android|ios|macos|web|all)
      [ -z "$PLATFORM" ] || fail "Specify only one platform."
      PLATFORM="$arg"
      ;;
    beta|store|direct)
      [ -z "$MODE" ] || fail "Specify only one mode."
      MODE="$arg"
      ;;
    release)
      [ -z "$MODE" ] || fail "Specify only one mode."
      MODE="store"
      ;;
    --build) VERSION_BUMP="build" ;;
    --patch) VERSION_BUMP="patch" ;;
    --minor) VERSION_BUMP="minor" ;;
    --major) VERSION_BUMP="major" ;;
    --no-increment) NO_INCREMENT=true ;;
    --skip-clean) SKIP_CLEAN=true ;;
    --skip-rust) SKIP_RUST=true ;;
    --skip-verify) SKIP_VERIFY=true ;;
    --cleanup) CLEAN_AFTER_RELEASE=true ;;
    -h|--help|help)
      show_usage
      exit 0
      ;;
    *) fail "Unknown argument: $arg. Run with --help." ;;
  esac
done

PLATFORM="${PLATFORM:-all}"
MODE="${MODE:-beta}"

if [ "$PLATFORM" != "all" ] && ! supports_platform "$PLATFORM"; then
  fail "$APP_NAME does not support '$PLATFORM'. Supported: $SUPPORTED_PLATFORMS"
fi

bump_version() {
  if [ "$NO_INCREMENT" = true ]; then
    log "Keeping version $(grep '^version:' "$APP_DIR/pubspec.yaml" | awk '{print $2}')."
    return
  fi

  local version_line
  local version_name
  local build_number
  local major
  local minor
  local patch
  local next_build

  version_line="$(grep -E '^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$' "$APP_DIR/pubspec.yaml" || true)"
  [[ "$version_line" =~ ^version:[[:space:]]*([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)$ ]] ||
    fail "pubspec.yaml must contain a version such as: version: 1.2.3+45"

  major="${BASH_REMATCH[1]}"
  minor="${BASH_REMATCH[2]}"
  patch="${BASH_REMATCH[3]}"
  build_number="${BASH_REMATCH[4]}"
  next_build="${BUILD_NUMBER:-$((build_number + 1))}"

  [[ "$next_build" =~ ^[0-9]+$ ]] || fail "BUILD_NUMBER must be a positive integer."
  [ "$next_build" -gt "$build_number" ] ||
    fail "BUILD_NUMBER must be greater than the current build number ($build_number)."

  case "$VERSION_BUMP" in
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
    build) ;;
  esac

  version_name="$major.$minor.$patch"
  perl -i -pe "s/^version:[[:space:]]*.*\$/version: ${version_name}+${next_build}/" "$APP_DIR/pubspec.yaml"
  ok "Version updated to ${version_name}+${next_build}."
}

check_dependencies() {
  command -v flutter >/dev/null 2>&1 || fail "Flutter is not installed."

  if platform_selected android && supports_platform android; then
    check_file "$APP_DIR/$ANDROID_KEY_PROPERTIES" "Android signing configuration"
  fi

  if platform_selected ios && supports_platform ios; then
    [ "$(uname -s)" = "Darwin" ] || fail "iOS releases require macOS."
    command -v pod >/dev/null 2>&1 || fail "CocoaPods is not installed."
  fi

  if platform_selected macos && supports_platform macos; then
    [ "$(uname -s)" = "Darwin" ] || fail "macOS releases require macOS."
  fi

  if [ "$MODE" != "direct" ]; then
    if { platform_selected android && supports_platform android; } ||
       { platform_selected ios && supports_platform ios; }; then
      command -v fastlane >/dev/null 2>&1 ||
        fail "Fastlane is not installed for Ruby $(cat "$PROJECT_ROOT/.ruby-version")."
    fi

    if platform_selected android && supports_platform android; then
      check_file "${ANDROID_SERVICE_ACCOUNT_JSON:-$HOME/.android/service-account.json}" \
        "Google Play service account key"
    fi

    if platform_selected ios && supports_platform ios; then
      check_file "${APP_STORE_CONNECT_API_KEY_JSON:-$HOME/.appstoreconnect/api_key.json}" \
        "App Store Connect API key"
    fi
  fi

  if [ -n "$DART_DEFINE_FILE" ]; then
    check_file "$APP_DIR/$DART_DEFINE_FILE" "Dart define file"
  fi

  if [ -n "$ADS_GUARD_FILE" ] &&
     ! grep -Eq '^[[:space:]]*static[[:space:]]+const[[:space:]]+bool[[:space:]]+adsEnabled[[:space:]]*=[[:space:]]*true[[:space:]]*;' "$APP_DIR/$ADS_GUARD_FILE"; then
    fail "adsEnabled must be true in $ADS_GUARD_FILE."
  fi
}

prepare_project() {
  if [ "$VERIFY_BACKEND" = true ] && [ "$MODE" != "direct" ] && [ "$SKIP_VERIFY" = false ]; then
    "$PROJECT_ROOT/scripts/verify_subscription_backend.sh"
  fi

  if [ "$PREPARE_RUST" = true ] && [ "$SKIP_RUST" = false ]; then
    log "Building Rust code and regenerating the Flutter bridge..."
    (cd "$PROJECT_ROOT/app_sdk" && cargo build --release)
    (cd "$APP_DIR" && cargo build --release)
    (cd "$APP_DIR" && flutter_rust_bridge_codegen generate)
  fi

  cd "$APP_DIR"
  if [ "$SKIP_CLEAN" = false ]; then
    flutter clean
  fi
  flutter pub get

  if grep -q 'build_runner:' pubspec.yaml; then
    dart run build_runner build --delete-conflicting-outputs
  fi

  if [ -f l10n.yaml ]; then
    flutter gen-l10n
  fi
}

flutter_build() {
  if [ -n "$DART_DEFINE_FILE" ]; then
    flutter build "$@" --dart-define-from-file="$DART_DEFINE_FILE"
  else
    flutter build "$@"
  fi
}

build_android() {
  log "Building Android AAB..."
  (cd "$APP_DIR" && flutter_build appbundle --release)
  ok "Android AAB: $APP_DIR/build/app/outputs/bundle/release/"

  if [ "$MODE" != "direct" ]; then
    log "Uploading Android with Fastlane lane '$MODE'..."
    (cd "$APP_DIR/android" && FASTLANE_SKIP_UPDATE_CHECK=1 FASTLANE_HIDE_CHANGELOG=1 fastlane "$MODE")
  fi
}

build_ios() {
  log "Installing iOS pods..."
  (cd "$APP_DIR/ios" && pod install)

  log "Building iOS IPA..."
  (cd "$APP_DIR" && flutter_build ipa --release)
  ok "iOS IPA: $APP_DIR/build/ios/ipa/"

  if [ "$MODE" != "direct" ]; then
    log "Uploading iOS with Fastlane lane '$MODE'..."
    (cd "$APP_DIR/ios" && FASTLANE_SKIP_UPDATE_CHECK=1 FASTLANE_HIDE_CHANGELOG=1 fastlane "$MODE")
  fi
}

build_macos() {
  if [ "$MODE" = "direct" ]; then
    log "Building macOS app..."
    (cd "$APP_DIR" && flutter_build macos --release)
    ok "macOS app: $APP_DIR/build/macos/Build/Products/Release/"
    return
  fi

  [ -n "$LEGACY_MACOS_DEPLOY_SCRIPT" ] ||
    fail "No macOS uploader is configured for $APP_NAME."

  log "Building and uploading macOS..."
  "$PROJECT_ROOT/$LEGACY_MACOS_DEPLOY_SCRIPT" macos \
    --no-increment --skip-clean --skip-rust --skip-verify
}

build_web() {
  log "Building web release..."
  (cd "$APP_DIR" && flutter_build web --release)
  ok "Web output: $APP_DIR/build/web/"

  if [ "$MODE" != "direct" ]; then
    warn "No web hosting target is configured. The web artifact was built but not uploaded."
  fi
}

cleanup_build_artifacts() {
  log "Cleaning Flutter build artifacts..."
  (cd "$APP_DIR" && flutter clean)
  (cd "$APP_DIR" && flutter pub get)
  if grep -q 'build_runner:' "$APP_DIR/pubspec.yaml"; then
    (cd "$APP_DIR" && dart run build_runner build --delete-conflicting-outputs)
  fi
  ok "Build artifacts cleaned."
}

run_platform() {
  case "$1" in
    android) build_android ;;
    ios) build_ios ;;
    macos) build_macos ;;
    web) build_web ;;
  esac
}

main() {
  log "Release target: $PLATFORM ($MODE)"
  check_dependencies
  bump_version
  prepare_project

  if [ "$PLATFORM" = "all" ]; then
    local platform
    for platform in $SUPPORTED_PLATFORMS; do
      run_platform "$platform"
    done
  else
    run_platform "$PLATFORM"
  fi

  if [ "$CLEAN_AFTER_RELEASE" = true ]; then
    cleanup_build_artifacts
  fi

  ok "Release finished."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main
fi
