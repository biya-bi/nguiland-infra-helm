{{- define "artifactory-common.artifactory-script" -}}
#!/usr/bin/env bash

set -uo pipefail

artifactory::is_ready() {
  local url="${ARTIFACTORY_PING_URL}"

  if [[ "${DEBUG:-0}" == "1" ]]; then
    wget -q -T 2 --tries=1 --spider "${url}"
  else
    wget -q -T 2 --tries=1 --spider "${url}" 2>/dev/null
  fi
}
{{ end }}