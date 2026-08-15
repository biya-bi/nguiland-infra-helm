{{- define "artifactory-common.colors-script" -}}
#!/usr/bin/env bash

readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_OFF='\033[0m'
{{- end -}}