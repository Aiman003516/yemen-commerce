#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFINES_FILE="${FLUTTER_DEFINES_FILE:-$ROOT_DIR/config/flutter_defines.json}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

usage() {
  cat <<'EOF'
Usage:
  tools/flutter_yemen.sh setup [all|customer|creator]
  tools/flutter_yemen.sh doctor
  tools/flutter_yemen.sh analyze [all|customer|creator]
  tools/flutter_yemen.sh test [all|customer|creator]
  tools/flutter_yemen.sh run <customer|creator> <web|android|ios> [debug|profile]
  tools/flutter_yemen.sh build <customer|creator> <web|apk|appbundle|ios> [debug|profile|release]

Examples:
  tools/flutter_yemen.sh setup all
  tools/flutter_yemen.sh run customer web debug
  tools/flutter_yemen.sh run creator android debug
  tools/flutter_yemen.sh build customer web release
  tools/flutter_yemen.sh build customer appbundle release
  tools/flutter_yemen.sh build creator ios release

The script reads config/flutter_defines.json, which is local-only and ignored by Git.
It rejects files containing service-role/provider/private-key material.
EOF
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Command not found: $1. Install it or set FLUTTER_BIN to the Flutter executable."
}

require_defines() {
  [[ -f "$DEFINES_FILE" ]] || fail "Missing $DEFINES_FILE. Copy config/flutter_defines.example.json to config/flutter_defines.json and fill the public Supabase values."
  if grep -Eiq 'service[_-]?role|SUPABASE_SERVICE_ROLE_KEY|AI_PROVIDER_API_KEY|BEGIN (RSA|OPENSSH|EC|PRIVATE) KEY|private_key' "$DEFINES_FILE"; then
    fail "Refusing to use a configuration file containing service-role, provider, or private-key material. Flutter config may contain only public compile-time values."
  fi
}

app_dir() {
  case "$1" in
    customer) printf '%s/flutter_app\n' "$ROOT_DIR" ;;
    creator) printf '%s/creator_app\n' "$ROOT_DIR" ;;
    *) fail "Unknown app '$1'. Use customer or creator." ;;
  esac
}

run_flutter() {
  local app_dir_path="$1"
  shift
  (cd "$app_dir_path" && "$FLUTTER_BIN" "$@")
}

setup_app() {
  local app="$1"
  run_flutter "$(app_dir "$app")" pub get
}

for_each_app() {
  local action="$1"
  local selection="${2:-all}"
  case "$selection" in
    all) "$action" customer; "$action" creator ;;
    customer|creator) "$action" "$selection" ;;
    *) fail "Unknown app selection '$selection'. Use all, customer, or creator." ;;
  esac
}

validate_target() {
  case "$1:$2" in
    web:debug|web:profile|web:release|android:debug|android:profile|android:release|ios:debug|ios:profile|ios:release|apk:debug|apk:profile|apk:release|appbundle:release) ;;
    *) fail "Unsupported target/mode '$1' '$2'. See tools/flutter_yemen.sh help." ;;
  esac
}

main() {
  local command="${1:-help}"
  case "$command" in
    help|-h|--help)
      usage
      ;;
    doctor)
      require_command "$FLUTTER_BIN"
      "$FLUTTER_BIN" doctor -v
      ;;
    setup)
      require_command "$FLUTTER_BIN"
      for_each_app setup_app "${2:-all}"
      ;;
    analyze)
      require_command "$FLUTTER_BIN"
      local selection="${2:-all}";
      case "$selection" in
        all) run_flutter "$(app_dir customer)" analyze; run_flutter "$(app_dir creator)" analyze ;;
        customer|creator) run_flutter "$(app_dir "$selection")" analyze ;;
        *) fail "Unknown app selection '$selection'. Use all, customer, or creator." ;;
      esac
      ;;
    test)
      require_command "$FLUTTER_BIN"
      local selection="${2:-all}"
      case "$selection" in
        all) run_flutter "$(app_dir customer)" test; run_flutter "$(app_dir creator)" test ;;
        customer|creator) run_flutter "$(app_dir "$selection")" test ;;
        *) fail "Unknown app selection '$selection'. Use all, customer, or creator." ;;
      esac
      ;;
    run|build)
      [[ $# -ge 3 ]] || fail "Usage: $command <customer|creator> <target> [mode]"
      local app="$2"
      local target="$3"
      local mode="${4:-debug}"
      local directory
      directory="$(app_dir "$app")"
      require_command "$FLUTTER_BIN"
      require_defines
      validate_target "$target" "$mode"
      if [[ "$command" == run && "$target" == web && "$mode" == release ]]; then
        fail "Use 'build customer web release' for Web release artifacts; run is for debug/profile sessions."
      fi
      local args=()
      case "$command:$target:$mode" in
        run:web:debug) args=(run -d chrome --debug) ;;
        run:web:profile) args=(run -d chrome --profile) ;;
        run:android:debug) args=(run -d android --debug) ;;
        run:android:profile) args=(run -d android --profile) ;;
        run:ios:debug) args=(run -d ios --debug) ;;
        run:ios:profile) args=(run -d ios --profile) ;;
        build:web:debug) args=(build web --debug) ;;
        build:web:profile) args=(build web --profile) ;;
        build:web:release) args=(build web --release) ;;
        build:apk:debug) args=(build apk --debug) ;;
        build:apk:profile) args=(build apk --profile) ;;
        build:apk:release) args=(build apk --release) ;;
        build:appbundle:release) args=(build appbundle --release) ;;
        build:ios:debug) args=(build ios --debug) ;;
        build:ios:profile) args=(build ios --profile) ;;
        build:ios:release) args=(build ipa --release) ;;
        *) fail "Unsupported command/target/mode combination." ;;
      esac
      run_flutter "$directory" "${args[@]}" --dart-define-from-file="$DEFINES_FILE"
      ;;
    *)
      usage
      exit 2
      ;;
  esac
}

main "$@"
