{{- define "artifactory-common.clear-archive-script" -}}
#!/usr/bin/env bash

set -uo pipefail

REAL_PATH=$(echo "${BASH_SOURCE[0]}" | sed 's/\/\.\.[^/]*//g')

readonly CLEANUP_DIR="$(cd "$(dirname "${REAL_PATH}")" && pwd)"
readonly UTIL_DIR="$(cd "${CLEANUP_DIR}/../util" && pwd)"

. "${UTIL_DIR}/logger.sh"
. "${UTIL_DIR}/artifactory.sh"

cleanup::clear_archive() {
  if ! artifactory::is_ready; then
    logger::warn "Artifactory not initialized yet, skipping cleanup"
    return 0
  fi

  logger::info "Clearing archive"

  local dir="/var/opt/jfrog/artifactory"

  if [ ! -d "${dir}" ]; then
    logger::error "Directory does not exist: ${dir}"
    return 0
  fi

  local system_yaml="/var/opt/jfrog/artifactory/etc/system.yaml"

  if [ ! -f "${system_yaml}" ]; then
    logger::error "File does not exist: ${system_yaml}"
    return 0
  fi

  local raw_allow
  raw_allow="$(awk '
    /^[^[:space:]]/ {in_obs=0; in_cons=0}
    /observability:/ {in_obs=1}
    in_obs && /consumption:/ {in_cons=1}
    in_cons && /^[[:space:]]*allow:/ {
      sub(/.*allow:[[:space:]]*/, "", $0)
      print
      exit
    }
  ' "$system_yaml" 2>/dev/null || true)"

  local allow
  allow=$(printf '%s\n' "$raw_allow" | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//' -e 's/"//g' -e "s/'//g")

  if [ -z "${allow// }" ]; then
    local archived_dir="$dir/data/metadata/usage/archived"

    if [ -d "$archived_dir" ]; then
      if [ -n "$(find "$archived_dir" -mindepth 1 -print -quit 2>/dev/null)" ]; then
        find "$archived_dir" -mindepth 1 -delete
        logger::info "Deleted contents of $archived_dir"
      else
        logger::info "No files to delete in $archived_dir"
      fi
    else
      logger::warn "Directory does not exist: $archived_dir"
    fi
  else
    logger::info "observability.consumption.allow is set to '$allow', skipping deletion"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cleanup::clear_archive
fi
{{ end }}
