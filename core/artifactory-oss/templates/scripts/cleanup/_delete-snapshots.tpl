{{- define "artifactory-oss.delete-snapshots-script" -}}
#!/usr/bin/env bash

set -uo pipefail

readonly SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UTIL_DIR="$(cd "${SCRIPTS_DIR}/../util" && pwd)"

readonly NO_OP_STATUS=2

source "${UTIL_DIR}/logger.sh"

cleanup::oss::snapshots::create_working_dir() {
  local working_dir
  working_dir="$(mktemp -d -t artifactory-oss-cleanup.XXXXXX)" || {
    logger::log_error "Failed to create temporary working directory"
    return 1
  }
  echo "$working_dir"
}

cleanup::oss::snapshots::generate_delete_list() {
  local working_dir="$1"
  local cutoff_epoch="$2"

  local offenders_file="${working_dir}/offenders.txt"
  local result_file="${working_dir}/result.json"
  local debug_file="${working_dir}/debug.txt"
  local protected_builds_file="${working_dir}/protected_builds.txt"
  local delete_file="${working_dir}/delete.txt"

  : > "$debug_file"

  # produce delete.txt from result.json and protected_builds.txt
  if ! jq -r --rawfile offenders "$offenders_file" '
      .results[]
      | select(.name != null and .name != "" and .name != "maven-metadata.xml")
      | select(.path as $p | ($offenders | split("\n") | map(select(length > 0)) | index($p)))
      | .created_epoch = (
          try (.created | split(".")[0] + "Z" | fromdateiso8601)
          catch 0
        )
      | "\(.path)|\(.name)|\(.created_epoch)"
    ' "$result_file" |
      gawk -v debug_file="$debug_file" \
          -F'|' \
          -v protected_file="$protected_builds_file" \
          -v cutoff_epoch="$cutoff_epoch" \
          -v keep="$KEEP" '
      function load_protected() {
        while ((getline line < protected_file) > 0) {
          split(line, parts, "|")
          protected[parts[1] "|" parts[2]] = 1
        }
      }

      function is_protected(key) {
        return (key in protected)
      }

      function extract_build(name) {
        if (name == "" || name == "null") return "UNKNOWN"
        if (match(name, /[0-9]{8}\.[0-9]{6}-[0-9]+/)) {
          return substr(name, RSTART, RLENGTH)
        }
        return "UNKNOWN"
      }

      BEGIN { 
      load_protected()
      }

      {
        path=$1
        name=$2
        epoch=$3

        # SAFETY: skip empty or invalid name
        if (name == "" || name == "null") next

        # SAFETY: skip invalid timestamps
        if (epoch == 0) next

        build=extract_build(name)

        # SAFETY: skip malformed builds
        if (build == "UNKNOWN") next

        key=path "|" build

        if (!(key in seen)) {
          seen[key]=1
          build_count[path]++
          build_order[path, build_count[path]] = build
        }

        file_count[key]++
        files[key] = files[key] "\n" path "/" name

        if (epoch > build_time[key]) {
          build_time[key] = epoch
        }
      }

      END {
        for (p in build_count) {

          # sort builds by recency
          for (i=1; i<=build_count[p]; i++) {
            for (j=i+1; j<=build_count[p]; j++) {
              b1=build_order[p,i]
              b2=build_order[p,j]

              if (build_time[p "|" b2] > build_time[p "|" b1]) {
                tmp=build_order[p,i]
                build_order[p,i]=build_order[p,j]
                build_order[p,j]=tmp
              }
            }
          }

          # --- DEBUG counters ---
          total_builds = build_count[p]
          skipped_latest_build = 0
          skipped_protected_build = 0
          skipped_by_keep = 0
          skipped_new_build = 0
          deleted_build = 0

          # Standard case: more builds than keep
          if (build_count[p] > keep) {
            for (i=1; i<=build_count[p]; i++) {
              build=build_order[p,i]
              key=p "|" build

              if (i == 1) { skipped_latest_build++; continue } # NEVER delete latest build
              if (is_protected(key)) { skipped_protected_build++; continue } # NEVER delete metadata build
              if (i <= keep) { skipped_by_keep++; continue }

              # SAFETY: respect age threshold
              if (build_time[key] > cutoff_epoch) { skipped_new_build++; continue }

              deleted_build++
              print files[key]
            }
          } else {
            for (i=1; i<=build_count[p]; i++) {
              build=build_order[p,i]
              key=p "|" build

              if (i == 1) { skipped_latest_build++; continue } # NEVER delete latest build
              if (is_protected(key)) { skipped_protected_build++; continue } # NEVER delete metadata build

              # SAFETY: delete ONLY if older than threshold
              if (build_time[key] <= cutoff_epoch) {
                deleted_build++
                print files[key]
              } else {
                skipped_new_build++
              }
            }
          }

          # --- DEBUG output per artifact ---
          printf("[%s] total=%d kept_latest=%d kept_protected=%d kept_by_keep=%d kept_new=%d deleted=%d\n",
            p, total_builds, skipped_latest_build, skipped_protected_build, skipped_by_keep, skipped_new_build, deleted_build) >> debug_file
        }
      }' | awk 'NF' | sort -u > "$delete_file"; then
    return 1
  fi

  while IFS= read -r line; do
    logger::log_debug "$line"
  done < "$debug_file"
}

cleanup::oss::snapshots::run_query() {
  local working_dir="$1"

  local query
  query=$(cat <<EOF
items.find({
  "repo": "$REPO",
  "path": {"\$match": "*SNAPSHOT*"}
}).include("repo","path","name","created")
EOF
  )

  local result_file="${working_dir}/result.json"

  logger::log_info "Running AQL query..."
  curl -sS --fail --connect-timeout 10 --max-time 60 \
    -u "$ART_OSS_USER:$ART_OSS_PASSWORD" \
    -X POST "$ART_OSS_URL/api/search/aql" \
    -H "Content-Type: text/plain" \
    -d "$query" > "$result_file" || {
      logger::log_error "curl failed while executing AQL query"
      return 1
    }
}

cleanup::oss::snapshots::validate_response() {
  local working_dir="$1"

  local result_file="${working_dir}/result.json"
  local tmp_file="${working_dir}/tmp.json"

  logger::log_info "---- RAW RESPONSE (first 20 lines) ----"
  head -n 20 "$result_file"
  logger::log_info "---------------------------------------"
  if ! jq empty "$result_file" >/dev/null 2>&1; then 
    logger::log_error "Artifactory did not return valid JSON";
    return 1;
  fi
  if jq -e '.errors' "$result_file" > /dev/null; then
    logger::log_error "Artifactory returned errors";
    jq . "$result_file";
    return 1;
  fi
  if ! jq 'if (.results == null or (.results | type != "array")) then .results = [] else . end' \
     "$result_file" > "$tmp_file" ||
     ! mv "$tmp_file" "$result_file"; then
    logger::log_error "Failed to normalize Artifactory response"
    return 1
  fi
  local total
  total=$(jq '.results | length' "$result_file")
  logger::log_info "Total artifacts returned: $total"
  if [ "$total" -eq 0 ]; then 
    return "$NO_OP_STATUS";
  fi
}

cleanup::oss::snapshots::get_offenders() {
  local working_dir="$1"

  local result_file="${working_dir}/result.json"
  local offenders_file="${working_dir}/offenders.txt"

  jq -r '.results[] | select(.name != null and .name != "" and .name != "maven-metadata.xml") | .path' "$result_file" | sort -u > "$offenders_file"
  local offender_count
  offender_count=$(grep -c . "$offenders_file" || true)
  logger::log_info "Artifacts requiring cleanup: $offender_count"
  if [ "$offender_count" -eq 0 ]; then
    logger::log_info "No cleanup required";
    return "$NO_OP_STATUS";
  fi
  logger::log_info "---- DEBUG: offender paths ----";
  cat "$offenders_file";
  logger::log_info "--------------------------------"
}

cleanup::oss::snapshots::fetch_protected_builds() {
  local working_dir="$1"

  local offenders_file="${working_dir}/offenders.txt"
  local metadata_file="${working_dir}/metadata.xml"
  local protected_builds_file="${working_dir}/protected_builds.txt"

  logger::log_info "Fetching maven-metadata.xml to protect active builds..."
  local meta_url
  > "$protected_builds_file"
  while read -r path; do
    meta_url="$ART_OSS_URL/$REPO/$path/maven-metadata.xml"
    if curl -sf --connect-timeout 5 --max-time 10 -u "$ART_OSS_USER:$ART_OSS_PASSWORD" "$meta_url" -o "$metadata_file"; then
      local build
      build=$(grep -oE '[0-9]{8}\.[0-9]{6}-[0-9]+' "$metadata_file" | head -n 1 || true)
      if [ -n "$build" ]; then
        echo "$path|$build" >> "$protected_builds_file";
      fi
    fi
  done < "$offenders_file"
  logger::log_info "---- Protected builds (from metadata) ----";
  cat "$protected_builds_file" || true; 
  logger::log_info "------------------------------------------"
}

cleanup::oss::snapshots::perform_deletion() {
  local working_dir="$1"
  local cutoff_epoch="$2"

  local delete_file="${working_dir}/delete.txt"

  if ! cleanup::oss::snapshots::generate_delete_list "$working_dir" "$cutoff_epoch"; then
    logger::log_error "Failed to generate delete list"
    return 1
  fi

  local delete_count
  delete_count=$(grep -c . "$delete_file" || true)
  logger::log_info "Files to delete: $delete_count"

  if [ "$delete_count" -eq 0 ]; then
    return "$NO_OP_STATUS"
  fi

  logger::log_debug "---- Files selected for deletion ----"; 
  cat "$delete_file"
  logger::log_info "--------------------------------------------"

  if [ "$DRY_RUN" = "true" ]; then
    logger::log_info "[DRY RUN] Skipping deletion"
    return "$NO_OP_STATUS"
  fi

  # -----------------------------
  # Parallel deletion with retry
  # -----------------------------
  logger::log_info "Starting parallel deletion..."

  if ! grep -v '^$' "$delete_file" | xargs -I {} -P "$MAX_PARALLEL" bash -c '
    util_dir="$1"
    file="$2"
    art_oss_user="$3"
    art_oss_password="$4"
    art_oss_url="$5"
    repo="$6"
    retries="$7"

    source "${util_dir}/logger.sh"

    # SAFETY: avoid dangerous deletes
    if echo "$file" | grep -q "\.\."; then
      logger::log_info "Skipping suspicious path: $file"
      exit 0
    fi

    for i in $(seq 1 "$retries"); do
      logger::log_info "Deleting $file (attempt $i)"
      if curl -sf --connect-timeout 10 --max-time 60 \
        -u "$art_oss_user:$art_oss_password" \
        -X DELETE "$art_oss_url/$repo/$file"; then
        logger::log_info "Deleted $file"
        exit 0
      fi
      sleep $((i * 2))
    done
    logger::log_error "Failed to delete $file"
    exit 1
  ' _ "$UTIL_DIR" {} "$ART_OSS_USER" "$ART_OSS_PASSWORD" "$ART_OSS_URL" "$REPO" "$RETRIES"; then
    logger::log_error "Failed to delete one or more files"
    exit 1
  fi

  logger::log_info "Cleanup complete"
}

cleanup::oss::snapshots::get_cutoff_epoch() {
  local now_epoch max_age
  max_age=${MAX_AGE_HOURS:-24}
  now_epoch=$(date +%s)
  echo $((now_epoch - max_age * 3600))
}

cleanup::oss::snapshots::handle_result() {
  local status="$1"

  case "$status" in
    0) ;;
    "$NO_OP_STATUS") exit 0 ;;
    *) exit "$status" ;;
  esac
}

cleanup::oss::snapshots::main() {
  local working_dir
  working_dir=$(cleanup::oss::snapshots::create_working_dir)
  cleanup::oss::snapshots::handle_result "$?"

  trap 'rm -rf "$working_dir"' EXIT

  logger::log_info "Created directory: $working_dir"

  logger::log_info "=== Artifactory Snapshot Cleanup ==="
  logger::log_info "Dry run: $DRY_RUN"

  local cutoff_epoch
  cutoff_epoch=$(cleanup::oss::snapshots::get_cutoff_epoch)
  cleanup::oss::snapshots::handle_result "$?"

  cleanup::oss::snapshots::run_query "$working_dir"
  cleanup::oss::snapshots::handle_result "$?"

  cleanup::oss::snapshots::validate_response "$working_dir"
  cleanup::oss::snapshots::handle_result "$?"

  cleanup::oss::snapshots::get_offenders "$working_dir"
  cleanup::oss::snapshots::handle_result "$?"

  cleanup::oss::snapshots::fetch_protected_builds "$working_dir"
  cleanup::oss::snapshots::handle_result "$?"

  cleanup::oss::snapshots::perform_deletion "$working_dir" "$cutoff_epoch"
  cleanup::oss::snapshots::handle_result "$?"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cleanup::oss::snapshots::main
fi

{{- end }}
