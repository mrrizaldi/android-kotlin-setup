#!/usr/bin/env bash
set -euo pipefail

# adrkt - tiny Android/Compose CLI to mimic a bit of "flutter run"
# Usage: adrkt <command> [--pkg P] [--act A] [--module app] [--variant debug] [--serial SERIAL] [--no-log] [--watch]
# See ADRKT_USAGE.md for details.

# Load local config if present
if [ -f .adrkt.conf ]; then
  # shellcheck disable=SC1091
  . ./.adrkt.conf
fi

MODULE="${MODULE:-app}"
VARIANT="${VARIANT:-debug}"
PKG="${PKG:-}"
ACT="${ACT:-}"
NAME="${NAME:-}"
DIR="${DIR:-}"
SERIAL="${ANDROID_SERIAL:-${SERIAL:-}}"
GRADLE="${GRADLE:-./gradlew}"
ADB="${ADB:-adb}"
NO_LOG=0
WATCH=0

usage() {
  cat <<'EOF'
adrkt - tiny Android/Compose dev helper

USAGE:
  adrkt <command> [options]

COMMANDS:
  create          Bootstrap a new Compose project
                  Usage: adrkt create --pkg com.example.app --name MyApp [--dir my-app]

  run             Build + install + start activity with logs
                  Add --watch to rebuild on file changes
                  Add --no-log to skip log tailing

  build           Assemble the variant (default :app:assembleDebug)
  install         Install the variant (default :app:installDebug)
  start           Start the activity (no force-stop)
  restart         Force-stop then start activity (≈ hot restart)
  reload          Re-install APK without restart (≈ hot reload, but not real)

  logs            Tail logcat filtered by package name
  devices         List connected adb devices

  test:unit       Run unit tests (:app:testDebugUnitTest)
  test:connected  Run instrumented tests (:app:connectedDebugAndroidTest)

  completion      Install shell completion
                  Usage: adrkt completion [bash|zsh|install]
  help            Show this help message

OPTIONS:
  For 'create' command:
    --pkg P       Package name (required, e.g., com.example.app)
    --name N      App name (required, e.g., MyApp)
    --dir D       Project directory (optional, auto-generated from name)

  For other commands:
    --pkg P       ApplicationId (e.g., com.example.app)
                  If omitted, auto-detect from build.gradle(.kts)

  --act A         Activity name (default: .MainActivity)
  --module M      Gradle module (default: app)
  --variant V     Build variant (default: debug)
  --serial S      Target specific device (or set $ANDROID_SERIAL)

  --no-log        Skip log tailing in 'run' command
  --watch         Rebuild on file changes (needs watchexec or entr)

  --gradle PATH   Path to gradle wrapper (default: ./gradlew)
  --adb PATH      Path to adb binary (default: adb)

  -h, --help      Show this help message

CONFIGURATION:
  Create .adrkt.conf in project root to set defaults:

    MODULE=app
    VARIANT=debug
    PKG=com.example.app
    ACT=.MainActivity

EXAMPLES:
  # Create a new project
  adrkt create --pkg com.example.myapp --name "My App"
  adrkt create --pkg com.acme.demo --name Demo --dir my-demo

  # Basic run with auto-detected package
  adrkt run

  # Run specific app and activity
  adrkt run --pkg com.example.myapp --act .SplashActivity

  # Watch mode for continuous development
  adrkt run --watch

  # Restart activity (like Flutter hot restart)
  adrkt restart

  # Just show logs
  adrkt logs

SHELL COMPLETION:
  # Auto-install for your shell
  adrkt completion install

  # Or manually for bash
  adrkt completion bash > ~/.local/share/bash-completion/completions/adrkt

  # Or manually for zsh
  adrkt completion zsh > ~/.local/share/zsh/site-functions/_adrkt

For more details, see ADRKT_USAGE.md

EOF
}

die() { echo "[err] $*" >&2; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

adb_cmd() {
  if [ -n "$SERIAL" ]; then
    "$ADB" -s "$SERIAL" "$@"
  else
    "$ADB" "$@"
  fi
}

ensure_gradle() {
  [ -x "$GRADLE" ] || die "Gradle wrapper not found at '$GRADLE'. Run in project root or set --gradle."
}

detect_pkg() {
  if [ -n "$PKG" ]; then return 0; fi
  local f1="$MODULE/build.gradle.kts"
  local f2="$MODULE/build.gradle"
  if [ -f "$f1" ]; then
    PKG=$(awk -F'"' '/applicationId *= *"/{print $2; exit}' "$f1" || true)
    if [ -z "$PKG" ]; then
      PKG=$(awk -F'"' '/namespace *= *"/{print $2; exit}' "$f1" || true)
    fi
  elif [ -f "$f2" ]; then
    PKG=$(awk -F'"' '/applicationId *"/{print $2; exit}' "$f2" || true)
    if [ -z "$PKG" ]; then
      PKG=$(awk -F"'" '/applicationId *'\''/{print $2; exit}' "$f2" || true)
    fi
  fi
  [ -n "$PKG" ] || die "Cannot detect applicationId. Pass --pkg or set PKG in .adrkt.conf"
}

detect_act() {
  if [ -n "$ACT" ]; then return 0; fi
  ACT=".MainActivity"
  local mf="$MODULE/src/main/AndroidManifest.xml"
  if [ -f "$mf" ]; then
    local cand
    cand=$(grep -oE '<activity[^>]*android:name="[^"]+"' "$mf" | head -n1 | sed -E 's/.*android:name="([^"]+)".*/\1/')
    if [ -n "$cand" ]; then ACT="$cand"; fi
  fi
}

build_task() {
  local t=":${MODULE}:assemble$(printf '%s' "$VARIANT" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
  echo "[adrkt] running $t"
  "$GRADLE" "$t"
}

install_task() {
  local t=":${MODULE}:install$(printf '%s' "$VARIANT" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
  echo "[adrkt] running $t"
  "$GRADLE" "$t"
}

cmd_build()   { ensure_gradle; build_task; }
cmd_install() { ensure_gradle; install_task; }
cmd_start()   { detect_pkg; detect_act; adb_cmd shell am start -n "${PKG}/${ACT}"; }
cmd_restart() { detect_pkg; detect_act; adb_cmd shell am start -S -n "${PKG}/${ACT}"; }
cmd_reload()  { ensure_gradle; install_task; }

cmd_logs()    { detect_pkg; adb_cmd logcat | grep -i --line-buffered "$PKG" || true; }
cmd_devices() { adb_cmd devices; }

cmd_run() {
  ensure_gradle; detect_pkg; detect_act
  build_task
  install_task
  cmd_restart
  if [ "$NO_LOG" -eq 0 ]; then
    echo "[adrkt] tailing logs for $PKG (Ctrl-C to quit)"
    cmd_logs
  fi
}

cmd_watch() {
  ensure_gradle; detect_pkg; detect_act
  has watchexec && watchexec -r -e kt,kts,xml "bash -lc '$GRADLE :$MODULE:install$(printf '%s' "$VARIANT" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}') && $ADB ${SERIAL:+-s $SERIAL} shell am start -S -n $PKG/$ACT'" && return 0
  has entr && { fd -e kt -e kts -e xml app | entr -r bash -lc "$GRADLE :$MODULE:install$(printf '%s' "$VARIANT" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}') && $ADB ${SERIAL:+-s $SERIAL} shell am start -S -n $PKG/$ACT"; return 0; }
  die "watch mode requires 'watchexec' or 'entr'"
}

cmd_completion() {
  local shell="${1:-auto}"
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # Auto-detect shell if needed
  if [ "$shell" = "auto" ] || [ "$shell" = "install" ]; then
    if [ -n "${BASH_VERSION:-}" ]; then
      shell="bash"
    elif [ -n "${ZSH_VERSION:-}" ]; then
      shell="zsh"
    else
      die "Cannot detect shell. Use: adrkt completion bash|zsh"
    fi
  fi

  case "$shell" in
    bash)
      if [ -f "$script_dir/completions/adrkt.bash" ]; then
        cat "$script_dir/completions/adrkt.bash"
      else
        die "Completion file not found: $script_dir/completions/adrkt.bash"
      fi
      ;;
    zsh)
      if [ -f "$script_dir/completions/adrkt.zsh" ]; then
        cat "$script_dir/completions/adrkt.zsh"
      else
        die "Completion file not found: $script_dir/completions/adrkt.zsh"
      fi
      ;;
    install)
      echo "[adrkt] Installing completion for $shell..."
      if [ "$shell" = "bash" ]; then
        local dest="$HOME/.local/share/bash-completion/completions"
        mkdir -p "$dest"
        cmd_completion bash > "$dest/adrkt"
        echo "[adrkt] ✓ Installed to $dest/adrkt"
        echo "[adrkt] Restart your shell or run: source ~/.bashrc"
      elif [ "$shell" = "zsh" ]; then
        local dest="$HOME/.local/share/zsh/site-functions"
        mkdir -p "$dest"
        cmd_completion zsh > "$dest/_adrkt"
        echo "[adrkt] ✓ Installed to $dest/_adrkt"
        echo "[adrkt] Add to ~/.zshrc: fpath=($dest \$fpath)"
        echo "[adrkt] Then restart your shell or run: source ~/.zshrc"
      fi
      ;;
    *)
      die "Unknown shell: $shell. Use: bash, zsh, or install"
      ;;
  esac
}

cmd_create() {
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local starter="$script_dir/starter.sh"

  # Check if starter.sh exists
  if [ ! -f "$starter" ]; then
    die "starter.sh not found at $starter. Make sure it's in the same directory as adrkt."
  fi

  if [ ! -x "$starter" ]; then
    chmod +x "$starter"
  fi

  [ -z "$PKG" ] && die "Package name required. Use: adrkt create --pkg com.example.app --name MyApp"
  [ -z "$NAME" ] && die "App name required. Use: adrkt create --pkg com.example.app --name MyApp"

  # Call starter.sh with arguments
  echo "[adrkt] Creating new project with starter.sh..."
  if [ -n "$DIR" ]; then
    "$starter" "$PKG" "$NAME" "$DIR"
  else
    "$starter" "$PKG" "$NAME"
  fi

  # Auto-generate .adrkt.conf in the created project
  local project_dir="${DIR:-$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')}"
  if [ -z "$project_dir" ]; then
    project_dir="$(printf '%s' "$PKG" | awk -F. '{print $NF}')"
  fi

  if [ -d "$project_dir" ]; then
    cat > "$project_dir/.adrkt.conf" <<EOF
MODULE=app
VARIANT=debug
PKG=$PKG
ACT=.MainActivity
EOF
    echo "[adrkt] Created .adrkt.conf in $project_dir/"
  fi

  echo ""
  echo "[adrkt] ✓ Project created successfully!"
  echo ""
  echo "Next steps:"
  echo "  cd $project_dir"
  echo "  adrkt run"
  echo ""
}

# Parse args
cmd="${1:-help}"
[ $# -gt 0 ] && shift

# Special handling for completion command to preserve its argument
if [ "$cmd" = "completion" ]; then
  cmd_completion "${1:-auto}"
  exit 0
fi

# Parse options for other commands
while [ $# -gt 0 ]; do
  case "$1" in
    --pkg)     PKG="${2:-}"; shift 2;;
    --name)    NAME="${2:-}"; shift 2;;
    --dir)     DIR="${2:-}"; shift 2;;
    --act)     ACT="${2:-}"; shift 2;;
    --module)  MODULE="${2:-}"; shift 2;;
    --variant) VARIANT="${2:-}"; shift 2;;
    --serial)  SERIAL="${2:-}"; shift 2;;
    --no-log)  NO_LOG=1; shift;;
    --watch)   WATCH=1; shift;;
    --gradle)  GRADLE="${2:-}"; shift 2;;
    --adb)     ADB="${2:-}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "[err] unknown option or arg: $1"; usage; exit 1;;
  esac
done

case "$cmd" in
  create)     cmd_create ;;
  run)        if [ "$WATCH" -eq 1 ]; then cmd_watch; else cmd_run; fi ;;
  build)      cmd_build ;;
  install)    cmd_install ;;
  start)      cmd_start ;;
  restart)    cmd_restart ;;
  reload)     cmd_reload ;;
  logs)       cmd_logs ;;
  devices)    cmd_devices ;;
  test:unit)  ensure_gradle; "$GRADLE" ":$MODULE:test$(printf '%s' "$VARIANT" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')UnitTest" ;;
  test:connected) ensure_gradle; "$GRADLE" ":$MODULE:connected$(printf '%s' "$VARIANT" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')AndroidTest" ;;
  help|*)     usage ;;
esac
