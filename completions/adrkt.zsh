args)
      case $words[1] in
        create)
          local -a create_options
          create_options=(
            '--pkg[Package name (required)]:package:'
            '--name[App name (required)]:name:'
            '--dir[Project directory (optional)]:directory:_files -/'
          )
          _arguments $create_options
          ;;
        completion)
          #compdef adrkt

# adrkt zsh completion

_adrkt() {
  local curcontext="$curcontext" state line
  typeset -A opt_args

  local -a commands
  commands=(
    'create:Bootstrap a new Compose project'
    'run:Build+install then start activity with logs'
    'build:Assemble the variant'
    'install:Install the variant'
    'start:Start activity without force-stop'
    'restart:Force-stop then start activity'
    'reload:Re-install APK without restart'
    'logs:Tail logcat filtered by package'
    'devices:List connected adb devices'
    'test\:unit:Run unit tests'
    'test\:connected:Run instrumented tests'
    'completion:Install shell completion'
    'help:Show help message'
  )

  _arguments -C \
    '1: :->command' \
    '*::arg:->args' \
    && return 0

  case $state in
    command)
      _describe -t commands 'adrkt command' commands
      ;;
    args)
      case $words[1] in
        create)
          local -a create_options
          create_options=(
            '--pkg[Package name (required)]:package:'
            '--name[App name (required)]:name:'
            '--dir[Project directory (optional)]:directory:_files -/'
          )
          _arguments $create_options
          ;;
        completion)
          _arguments '2:shell:(bash zsh install)'
          ;;
        *)
          local -a options
          options=(
            '--pkg[Application ID]:package:'
            '--act[Activity name]:activity:'
            '--module[Gradle module]:module:_adrkt_modules'
            '--variant[Build variant]:variant:(debug release)'
            '--serial[Device serial]:serial:_adrkt_devices'
            '--no-log[Skip log tailing]'
            '--watch[Rebuild on file changes]'
            '--gradle[Gradle wrapper path]:file:_files'
            '--adb[ADB path]:file:_files'
            '(- *)'{-h,--help}'[Show help message]'
          )
          _arguments $options
          ;;
      esac
      ;;
  esac
}

_adrkt_modules() {
  local -a modules
  if [[ -f settings.gradle.kts ]]; then
    modules=(${(f)"$(grep -oE 'include\(":[^"]+"\)' settings.gradle.kts 2>/dev/null | sed 's/include("://;s/")//')"})
  elif [[ -f settings.gradle ]]; then
    modules=(${(f)"$(grep -oE "include '[^']+'" settings.gradle 2>/dev/null | sed "s/include '://;s/'//")"})
  fi
  [[ ${#modules} -eq 0 ]] && modules=(app)
  _describe 'module' modules
}

_adrkt_devices() {
  local -a devices
  if (( $+commands[adb] )); then
    devices=(${(f)"$(adb devices 2>/dev/null | tail -n +2 | grep -v '^$' | awk '{print $1}')"})
  fi
  _describe 'device' devices
}

_adrkt "$@"
