# Android Kotlin Setup + `adrkt` CLI

This repo provides:
- `starter.sh`: bootstrap a minimal Android Jetpack Compose app from scratch via CLI.
- `adrkt`: a tiny CLI to streamline the dev loop (build, install, restart, logs).
- `install.sh`: installer to place `adrkt` on your PATH and enable shell completion.

## Quick Start

```bash
# 1) Bootstrap a project (example)
./starter.sh com.example.app "Example App" example-app

# 2) Build and run (from project root that contains ./gradlew)
adrkt run --pkg com.example.app --act .MainActivity
```

## Install `adrkt` globally (user-level)

```bash
chmod +x adrkt.sh install.sh
./install.sh
```

This will:
- Copy `adrkt` into `~/.local/bin/adrkt` and make it executable
- Generate user-level completion at `~/.local/share/bash-completion/completions/adrkt`
- Update your `~/.zshrc` and `~/.bashrc` idempotently
- Add `~/.local/bin` to your PATH if missing

Reload your shell:
```bash
# zsh
rm -f ~/.zcompdump* && exec zsh -l
# bash
source ~/.bashrc
```

### System-wide install (requires sudo)

```bash
sudo ./install.sh --mode system
```

This copies `adrkt` into `/usr/local/bin/adrkt`. Completion is still installed per-user so every user can opt-in.

### Custom install directory

```bash
./install.sh --bin-dir "$HOME/bin" --shell both
```

## Config

At your project root, create `.adrkt.conf`:

```bash
MODULE=app
VARIANT=debug
PKG=com.example.app
ACT=.MainActivity
```

You can still override via CLI flags.

## `adrkt` commands

```bash
adrkt run                # assemble+install+restart and tail logcat
adrkt run --watch        # rebuild on changes (needs watchexec or entr)
adrkt reload             # reinstall only (approx. to hot reload)
adrkt restart            # force-stop then start activity
adrkt build              # assembleDebug (by default)
adrkt install            # installDebug (by default)
adrkt start              # start activity without force-stop
adrkt logs               # filtered logs by package
adrkt devices            # list adb devices
adrkt test:unit          # unit tests
adrkt test:connected     # instrumented tests
```

Global options:
- `--pkg`, `--act`, `--module`, `--variant`, `--serial`
- `--gradle` custom wrapper path
- `--adb` custom adb path
- `--no-log` skip logs in `run`

## Requirements

- Android SDK tools in PATH (`adb`)
- Project with Gradle wrapper (`./gradlew`)
- JDK 17 or 21
- For watch mode: `watchexec` or `entr`
