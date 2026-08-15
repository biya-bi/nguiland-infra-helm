{{- define "artifactory-common.resources" -}}

{{ printf "---\n" }}
{{ include "artifactory-common.cleanup-scripts" . | printf "%s\n" }}
{{ printf "---\n" }}
{{ include "artifactory-common.util-scripts" . | printf "%s\n" }}
{{ printf "---\n" }}
{{ include "artifactory-common.data" . | printf "%s\n" }}
{{ printf "---\n" }}
{{ include "artifactory-common.entrypoint" . | printf "%s\n" }}
{{ printf "---\n" }}
{{ include "artifactory-common.hpa" . | printf "%s\n" }}
{{ printf "---\n" }}
{{ include "artifactory-common.ingress" . | printf "%s\n" }}
{{ printf "---\n" }}
{{ include "artifactory-common.service" . | printf "%s\n" }}
{{ printf "---\n" }}
{{ include "artifactory-common.serviceAccount" . | printf "%s\n" }}
{{ printf "---\n" }}
{{ include "artifactory-common.deployment" . | printf "%s\n" }}

{{- end -}}
