{{- define "artifactory-common.cleanup-start-script" -}}
#!/usr/bin/env bash

set -uo pipefail

REAL_PATH=$(echo "${BASH_SOURCE[0]}" | sed 's/\/\.\.[^/]*//g')

readonly CLEANUP_DIR="$(cd "$(dirname "${REAL_PATH}")" && pwd)"
readonly UTIL_DIR="$(cd "${CLEANUP_DIR}/../util" && pwd)"

. "${UTIL_DIR}/logger.sh"
. "${UTIL_DIR}/artifactory.sh"

cleanup::start() {
  logger::log_info "Cleanup sidecar started"

  local ready=0

  local sleep_duration_seconds=3600   # 1 hour

  while true; do
    if artifactory::is_ready; then
      if [[ "$ready" -ne 1 ]]; then
        logger::log_info "Artifactory is now available"
        ready=1
      fi

      cleanup::run_scripts
    else
      if [[ "$ready" -ne 0 ]]; then
        logger::log_warn "Artifactory became unavailable"
        ready=0
      else
        logger::log_debug "Artifactory still not ready"
      fi
    fi

    logger::log_info "Sleeping for ${sleep_duration_seconds}s..."
    sleep "${sleep_duration_seconds}"
  done
}

cleanup::run_scripts() {
  local count=0
  local duration=300 # 5 minutes
  local exit_code

  logger::log_info "Running cleanup scripts"

  # Run ALL scripts except logger and sidecar itself
  while IFS= read -r script; do
    ((++count))

    logger::log_info "Executing: ${script}"

    timeout "${duration}" bash "${script}"
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
      logger::log_info "Script succeeded: ${script}"
    elif [[ $exit_code -eq 124 ]]; then
      logger::log_warn "Script timed out (${duration}s): ${script}"
    else
      logger::log_warn "Script failed (exit ${exit_code}): ${script}"
    fi
  done < <(
    find -L "${CLEANUP_DIR}" \
      -type f \
      ! -path "*/.*" \
      -name "*.sh" \
      ! -name "start.sh" \
      ! -name "stop.sh" \
    | sort -V
  )

  if [[ "${count}" -eq 0 ]]; then
    logger::log_warn "No cleanup scripts found"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cleanup::start
fi
{{ end }}