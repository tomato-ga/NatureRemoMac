#!/usr/bin/env bash
set -euo pipefail

APP_NAME="NatureRemoMac"
MODE="run"
CONFIGURATION="debug"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.icns"
APP_INFO_SOURCE="$ROOT_DIR/Config/AppInfo.plist"
LOCALIZATION_SOURCE="$ROOT_DIR/Sources/NatureRemoMac/Resources/Localizable.xcstrings"

usage() {
  echo "usage: $0 [--build-only|--run|--verify|--debug|--logs|--telemetry] [--configuration debug|release]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-only|build-only)
      MODE="build-only"
      shift
      ;;
    --run|run)
      MODE="run"
      shift
      ;;
    --verify|verify)
      MODE="verify"
      shift
      ;;
    --debug|debug)
      MODE="debug"
      shift
      ;;
    --logs|logs)
      MODE="logs"
      shift
      ;;
    --telemetry|telemetry)
      MODE="telemetry"
      shift
      ;;
    --configuration)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      CONFIGURATION="$2"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

case "$CONFIGURATION" in
  debug|release) ;;
  *)
    usage
    exit 2
    ;;
esac

[[ -f "$APP_INFO_SOURCE" ]] || {
  echo "missing app metadata: $APP_INFO_SOURCE" >&2
  exit 1
}

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_INFO_SOURCE")"

clean_bundle_xattrs() {
  xattr -cr "$APP_BUNDLE"
  xattr -d com.apple.FinderInfo "$APP_BUNDLE" >/dev/null 2>&1 || true
}

build_app() {
  cd "$ROOT_DIR"

  swift build --configuration "$CONFIGURATION"
  local build_binary
  build_binary="$(swift build --configuration "$CONFIGURATION" --show-bin-path)/$APP_NAME"

  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$APP_RESOURCES"
  cp "$build_binary" "$APP_BINARY"
  cp "$APP_INFO_SOURCE" "$INFO_PLIST"
  chmod +x "$APP_BINARY"

  if [[ -f "$APP_ICON_SOURCE" ]]; then
    cp "$APP_ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"
  fi

  if [[ -f "$LOCALIZATION_SOURCE" ]]; then
    xcrun xcstringstool compile "$LOCALIZATION_SOURCE" --output-directory "$APP_RESOURCES"
  fi

  clean_bundle_xattrs
  codesign --force --sign - "$APP_BUNDLE"
  clean_bundle_xattrs
}

open_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  /usr/bin/open -n "$APP_BUNDLE"
  sleep 0.5
  clean_bundle_xattrs
}

build_app

case "$MODE" in
  build-only)
    echo "$APP_BUNDLE"
    ;;
  run)
    open_app
    ;;
  debug)
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    lldb -- "$APP_BINARY"
    ;;
  logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    clean_bundle_xattrs
    ;;
esac
