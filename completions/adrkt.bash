# adrkt bash completion

_adrkt_completion() {
  local cur prev commands options
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  commands="create run build install start restart reload logs test:unit test:connected devices help completion"
  options="--pkg --act --module --variant --serial --no-log --watch --gradle --adb --help"
  create_options="--pkg --name --dir"

  case "$prev" in
    --name|--dir)
      return 0
      ;;
    --module)
      if [ -f settings.gradle.kts ]; then
        local modules=$(grep -oE 'include\(":[^"]+"\)' settings.gradle.kts 2>/dev/null | sed 's/include("://;s/")//' | tr '\n' ' ')
        COMPREPLY=( $(compgen -W "$modules" -- "$cur") )
      elif [ -f settings.gradle ]; then
        local modules=$(grep -oE "include '[^']+'" settings.gradle 2>/dev/null | sed "s/include '://;s/'//" | tr '\n' ' ')
        COMPREPLY=( $(compgen -W "$modules" -- "$cur") )
      else
        COMPREPLY=( $(compgen -W "app" -- "$cur") )
      fi
      return 0
      ;;
    --variant)
      COMPREPLY=( $(compgen -W "debug release" -- "$cur") )
      return 0
      ;;
    --serial)
      if command -v adb >/dev/null 2>&1; then
        local devices=$(adb devices 2>/dev/null | tail -n +2 | grep -v "^$" | awk '{print $1}' | tr '\n' ' ')
        COMPREPLY=( $(compgen -W "$devices" -- "$cur") )
      fi
      return 0
      ;;
    completion)
      COMPREPLY=( $(compgen -W "bash zsh install" -- "$cur") )
      return 0
      ;;
    --pkg|--act|--gradle|--adb)
      return 0
      ;;
  esac

  # Check if we're completing for the create command
  local i cmd_found=0
  for ((i=1; i < ${#COMP_WORDS[@]}-1; i++)); do
    if [[ "${COMP_WORDS[i]}" == "create" ]]; then
      cmd_found=1
      break
    fi
  done

  if [[ $cmd_found -eq 1 ]]; then
    if [[ "$cur" == -* ]]; then
      COMPREPLY=( $(compgen -W "$create_options" -- "$cur") )
    fi
    return 0
  fi

  if [[ "$cur" == -* ]]; then
    COMPREPLY=( $(compgen -W "$options" -- "$cur") )
  else
    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
  fi
}

complete -F _adrkt_completion adrkt
