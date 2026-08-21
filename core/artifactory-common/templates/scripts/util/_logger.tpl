{{- define "artifactory-common.logger-script" -}}
#!/usr/bin/env bash

# Use a localized function block so variables don't leak into the global scope
logger::_init() {
  local util_dir
  util_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [[ -z "${COLOR_OFF+x}" ]]; then
    . "${util_dir}/colors.sh"
  fi
}
logger::_init
unset -f logger::_init # Clean up the initialization function from memory

logger::log() {
  local level_color="$1"
  local level_name="$2"
  local message="$3"
  local add_newline="${4:-true}"

  local timestamp
  timestamp=$(date +'%Y-%m-%dT%H:%M:%S')

  local nl=""
  [[ "${add_newline}" == "true" ]] && nl="\n"
  printf '%s %b%s%b %s%b' \
    "$timestamp" \
    "$level_color" \
    "$level_name" \
    "$COLOR_OFF" \
    "$message" \
    "$nl"
}

logger::debug() {
  logger::log "${COLOR_CYAN}" "DEBUG" "$1" "${2:-true}" >&2
}

logger::info() {
  logger::log "${COLOR_GREEN}" "INFO" "$1" "${2:-true}"
}

logger::warn() {
  logger::log "${COLOR_YELLOW}" "WARN" "$1" "${2:-true}" >&2
}

logger::error() {
  logger::log "${COLOR_RED}" "ERROR" "$1" "${2:-true}" >&2
}
{{- end -}}