#!/usr/bin/env bash
set -euo pipefail

# install.sh - installer for adrkt (Android/Compose dev helper CLI)
#
# This script:
#  - installs adrkt into a bin directory (default: ~/.local/bin)
#  - installs shell completion (user-level) for bash and zsh
#  - configures your shell rc files idempotently
#
# Options:
#   --mode user|system      Install for current user (default) or system-wide (needs sudo)
#   --bin-dir PATH          Target bin directory (default: ~/.local/bin or /usr/local/bin for system mode)
#   --shell auto|zsh|bash|both   Which shell completion to install (default: auto)
#   --no-completion         Skip completion installation
#   --no-rc                 Do not modify shell rc files
#   --dry-run               Show what would be done, do not write
#
# Usage:
#   ./install.sh
#   ./install.sh --mode system
#   ./install.sh --bin-dir \"$HOME/bin\" --shell both
#
# This script assumes adrkt is in the same directory as install.sh.

MODE=\"user\"
BIN_DIR=\"\"
SHELL_TARGET=\"auto\"
DO_COMPLETION=1
DO_RC=1
DRY_RUN=0

msg() { printf \"[install] %s\n\" \"$*\"; }
die() { printf \"[err] %s\n\" \"$*\" >&2; exit 1; }
run() { if [ \"$DRY_RUN\" -eq 1 ]; then echo \"+ $*\"; else eval \"$@\"; fi; }

# Parse args
while [ $# -gt 0 ]; do
  case \"$1\" in
    --mode)        MODE=\"${2:-}\"; shift 2;;
    --bin-dir)     BIN_DIR=\"${2:-}\"; shift 2;;
    --shell)       SHELL_TARGET=\"${2:-}\"; shift 2;;
    --no-completion) DO_COMPLETION=0; shift;;
    --no-rc)       DO_RC=0; shift;;
    --dry-run)     DRY_RUN=1; shift;;
    -h|--help)
      sed -n '1,80p' \"$0\"
      exit 0
      ;;
    *)
      die \"Unknown option: $1\"
      ;;
  esac
done

# Resolve paths
SCRIPT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]:-$0}\")\" && pwd)\"
ADRKT_SRC=\"$SCRIPT_DIR/adrkt.sh\"
[ -f \"$ADRKT_SRC\" ] || ADRKT_SRC=\"$SCRIPT_DIR/adrkt\"  # support already renamed
[ -f \"$ADRKT_SRC\" ] || die \"Cannot find adrkt script next to install.sh\"

# Decide bin dir
if [ -z \"$BIN_DIR\" ]; then
  if [ \"$MODE\" = \"system\" ]; then
    BIN_DIR=\"/usr/local/bin\"
  else
    BIN_DIR=\"${HOME}/.local/bin\"
  fi
fi

# Determine completion destinations
BASH_USER_DIR=\"${HOME}/.local/share/bash-completion/completions\"
BASH_USER_FILE=\"${BASH_USER_DIR}/adrkt\"

# Ensure bin dir
if [ ! -d \"$BIN_DIR\" ]; then
  msg \"Creating bin dir: $BIN_DIR\"
  run \"mkdir -p \\\"$BIN_DIR\\\"\"
fi

TARGET_BIN=\"${BIN_DIR}/adrkt\"

# Copy adrkt
msg \"Installing adrkt to $TARGET_BIN\"
if [ \"$MODE\" = \"system\" ]; then
  run \"sudo cp \\\"$ADRKT_SRC\\\" \\\"$TARGET_BIN\\\"\"
  run \"sudo chmod +x \\\"$TARGET_BIN\\\"\"
else
  run \"cp \\\"$ADRKT_SRC\\\" \\\"$TARGET_BIN\\\"\"
  run \"chmod +x \\\"$TARGET_BIN\\\"\"
fi

# PATH hint function
ensure_path_export() {
  local rc=\"$1\"
  local path_line='export PATH=\"$HOME/.local/bin:$PATH\"'
  grep -Fq \"$path_line\" \"$rc\" 2>/dev/null || {
    msg \"Adding ~/.local/bin to PATH in $rc\"
    run \"printf '\\n# adrkt PATH\\n%s\\n' '$path_line' >> \\\"$rc\\\"\"
  }
}

# Append-once helper
append_once() {
  local rc=\"$1\"; shift
  local marker=\"$1\"; shift
  local content=\"$*\"
  grep -Fq \"$marker\" \"$rc\" 2>/dev/null || {
    msg \"Updating $rc\"
    run \"printf '\\n%s\\n%s\\n' \\\"$marker\\\" \\\"$content\\\" >> \\\"$rc\\\"\"
  }
}

# Install completion content writer
write_completion_user() {
  # ensure dir
  [ \"$DO_COMPLETION\" -eq 1 ] || return 0
  run \"mkdir -p \\\"$BASH_USER_DIR\\\"\"
  # generate from installed adrkt to ensure current version
  local gen_cmd='\"'$TARGET_BIN'\" completion > \"'$BASH_USER_FILE'\"'
  msg \"Writing user-level completion to $BASH_USER_FILE\"
  run \"$gen_cmd\"
}

# Setup zsh rc
setup_zsh() {
  local zrc=\"${HOME}/.zshrc\"
  [ \"$DO_RC\" -eq 1 ] || return 0
  # backup
  [ -f \"$zrc\" ] && run \"cp \\\"$zrc\\\" \\\"${zrc}.bak.$(date +%s)\\\"\"
  ensure_path_export \"$zrc\"
  local marker=\"# >>> adrkt zsh completion >>>\"
  read -r -d '' block <<'ZRC'
autoload -Uz compinit bashcompinit
compinit
bashcompinit
# source user-level completion file
if [ -r \"$HOME/.local/share/bash-completion/completions/adrkt\" ]; then
  source \"$HOME/.local/share/bash-completion/completions/adrkt\"
fi
ZRC
  append_once \"$zrc\" \"$marker\" \"$block\"
}

# Setup bash rc
setup_bash() {
  local brc=\"${HOME}/.bashrc\"
  [ \"$DO_RC\" -eq 1 ] || return 0
  # backup
  [ -f \"$brc\" ] && run \"cp \\\"$brc\\\" \\\"${brc}.bak.$(date +%s)\\\"\"
  ensure_path_export \"$brc\"
  local marker=\"# >>> adrkt bash completion >>>\"
  read -r -d '' block <<'BRC'
# Load user-level completion for adrkt if available
if [ -r \"$HOME/.local/share/bash-completion/completions/adrkt\" ]; then
  source \"$HOME/.local/share/bash-completion/completions/adrkt\"
fi
BRC
  append_once \"$brc\" \"$marker\" \"$block\"
}

# Select which shells
detect_shell_target() {
  case \"$SHELL_TARGET\" in
    auto) echo \"both\" ;;
    zsh|bash|both) echo \"$SHELL_TARGET\" ;;
    *) echo \"both\" ;;
  esac
}

# Execute steps
if [ \"$DO_COMPLETION\" -eq 1 ]; then
  write_completion_user
  case \"$(detect_shell_target)\" in
    both) setup_zsh; setup_bash ;;
    zsh)  setup_zsh ;;
    bash) setup_bash ;;
  esac
fi

msg \"Installation complete.\"
msg \"If using zsh, reload and rebuild completion cache:\"
msg \"  rm -f ~/.zcompdump* && exec zsh -l\"
msg \"If using bash, restart your shell or run: source ~/.bashrc\"
