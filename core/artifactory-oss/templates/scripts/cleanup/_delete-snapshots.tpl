{{- define "artifactory-oss.delete-snapshots-script" -}}
#!/usr/bin/env bash

set -uo pipefail

cleanup::oss::snapshots::generate_delete_list() {
  local cutoff_epoch="$1"
  # produce delete.txt from result.json and protected_builds.txt
  jq -r --rawfile offenders offenders.txt '
    .results[]
    | select(.name != null and .name != "" and .name != "maven-metadata.xml")
    | select(.path as $p | ($offenders | split("\n") | map(select(length > 0)) | index($p)))
    | .created_epoch = (
        try (.created | split(".")[0] + "Z" | fromdateiso8601)
        catch 0
      )
    | "\(.path)|\(.name)|\(.created_epoch)"
  ' result.json |
    gawk -F'|' -v protected_file="protected_builds.txt" -v cutoff_epoch="$cutoff_epoch" -v keep="$KEEP" '
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
        printf("DEBUG [%s] total=%d kept_latest=%d kept_protected=%d kept_by_keep=%d kept_new=%d deleted=%d\n",
          p, total_builds, skipped_latest_build, skipped_protected_build, skipped_by_keep, skipped_new_build, deleted_build) > "/dev/stderr"
      }
    }' | grep -v '^$' | sort -u > delete.txt || true
}

cleanup::oss::snapshots::run_query() {
  local query
  query=$(cat <<EOF
items.find({
  "repo": "$REPO",
  "path": {"\$match": "*SNAPSHOT*"}
}).include("repo","path","name","created")
EOF
  )

  echo "Running AQL query..."
  curl -sS --fail --connect-timeout 10 --max-time 60 \
    -u "$ART_OSS_USER:$ART_OSS_PASSWORD" \
    -X POST "$ART_OSS_URL/api/search/aql" \
    -H "Content-Type: text/plain" \
    -d "$query" > result.json || { echo "ERROR: curl failed"; exit 1; }
}

cleanup::oss::snapshots::validate_response() {
  echo "---- RAW RESPONSE (first 20 lines) ----"
  head -n 20 result.json
  echo "---------------------------------------"
  if ! jq empty result.json >/dev/null 2>&1; then 
    echo "ERROR: Artifactory did not return valid JSON";
    exit 1;
  fi
  if jq -e '.errors' result.json > /dev/null; then
    echo "ERROR: Artifactory returned errors";
    jq . result.json;
    exit 1;
  fi
  jq 'if (.results == null or (.results | type != "array")) then .results = [] else . end' result.json > tmp.json && mv tmp.json result.json
  local total
  total=$(jq '.results | length' result.json)
  echo "Total artifacts returned: $total"
  if [ "$total" -eq 0 ]; then 
    echo "No artifacts found. Exiting.";
    exit 0;
  fi
}

cleanup::oss::snapshots::get_offenders() {
  jq -r '.results[] | select(.name != null and .name != "" and .name != "maven-metadata.xml") | .path' result.json | sort -u > offenders.txt
  local offender_count
  offender_count=$(grep -c . offenders.txt || true)
  echo "Artifacts requiring cleanup: $offender_count"
  if [ "$offender_count" -eq 0 ]; then
    echo "No cleanup required.";
    exit 0;
  fi
  echo "---- DEBUG: offender paths ----";
  cat offenders.txt;
  echo "--------------------------------"
}

cleanup::oss::snapshots::fetch_protected_builds() {
  echo "Fetching maven-metadata.xml to protect active builds..."
  local meta_url
  > protected_builds.txt
  while read -r path; do
    meta_url="$ART_OSS_URL/$REPO/$path/maven-metadata.xml"
    if curl -sf --connect-timeout 5 --max-time 10 -u "$ART_OSS_USER:$ART_OSS_PASSWORD" "$meta_url" -o meta.xml; then
      local build
      build=$(grep -oE '[0-9]{8}\.[0-9]{6}-[0-9]+' meta.xml | head -n 1 || true)
      if [ -n "$build" ]; then
        echo "$path|$build" >> protected_builds.txt;
      fi
    fi
  done < offenders.txt
  echo "---- Protected builds (from metadata) ----";
  cat protected_builds.txt || true; 
  echo "------------------------------------------"
}

cleanup::oss::snapshots::perform_deletion() {
  local cutoff_epoch="$1"
  cleanup::oss::snapshots::generate_delete_list "$cutoff_epoch"
  local delete_count
  delete_count=$(grep -c . delete.txt || true)
  echo "Files to delete: $delete_count"

  if [ "$delete_count" -eq 0 ]; then
    echo "Nothing to delete."
    exit 0
  fi

  echo "---- DEBUG: files selected for deletion ----"; 
  cat delete.txt
  echo "--------------------------------------------"

  if [ "$DRY_RUN" = "true" ]; then
    echo "[DRY RUN] Skipping deletion."
    exit 0
  fi

  # -----------------------------
  # Parallel deletion with retry
  # -----------------------------
  echo "Starting parallel deletion..."

  cat delete.txt | grep -v '^$' | xargs -I {} -P "$MAX_PARALLEL" bash -c '
    file="$1"
    art_oss_user="$2"
    art_oss_password="$3"
    art_oss_url="$4"
    repo="$5"
    retries="$6"

    # SAFETY: avoid dangerous deletes
    if echo "$file" | grep -q "\.\."; then
      echo "Skipping suspicious path: $file"
      exit 0
    fi

    for i in $(seq 1 "$retries"); do
      echo "Deleting $file (attempt $i)"
      if curl -sf --connect-timeout 10 --max-time 60 \
        -u "$art_oss_user:$art_oss_password" \
        -X DELETE "$art_oss_url/$repo/$file"; then
        echo "Deleted $file"
        exit 0
      fi
      sleep $((i * 2))
    done
    echo "FAILED to delete $file" >&2
    exit 1
  ' _ {} "$ART_OSS_USER" "$ART_OSS_PASSWORD" "$ART_OSS_URL" "$REPO" "$RETRIES"

  echo "Cleanup complete."
}

cleanup::oss::snapshots::get_cutoff_epoch() {
  local now_epoch max_age
  max_age=${MAX_AGE_HOURS:-24}
  now_epoch=$(date +%s)
  echo $((now_epoch - max_age * 3600))
}

cleanup::oss::snapshots::main() {
  # Ensure we are in a writable directory
  cd /tmp

  echo "=== Artifactory Snapshot Cleanup ==="
  echo "Dry run: $DRY_RUN"

  local cutoff_epoch
  cutoff_epoch=$(cleanup::oss::snapshots::get_cutoff_epoch)

  cleanup::oss::snapshots::run_query
  cleanup::oss::snapshots::validate_response
  cleanup::oss::snapshots::get_offenders
  cleanup::oss::snapshots::fetch_protected_builds
  cleanup::oss::snapshots::perform_deletion "$cutoff_epoch"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cleanup::oss::snapshots::main
fi

{{- end }}
