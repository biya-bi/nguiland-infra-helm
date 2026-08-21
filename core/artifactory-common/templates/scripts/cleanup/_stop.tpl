{{- define "artifactory-common.cleanup-stop-script" -}}
#!/usr/bin/env bash

set -uo pipefail

REAL_PATH=$(echo "${BASH_SOURCE[0]}" | sed 's/\/\.\.[^/]*//g')

readonly CLEANUP_DIR="$(cd "$(dirname "${REAL_PATH}")" && pwd)"
readonly UTIL_DIR="$(cd "${CLEANUP_DIR}/../util" && pwd)"

. "${UTIL_DIR}/logger.sh"

cleanup::stop() {
  logger::info "Stopping cleanup sidecar"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cleanup::stop
fi
{{ end }}