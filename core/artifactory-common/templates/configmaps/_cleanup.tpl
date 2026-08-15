{{- define "artifactory-common.cleanup-scripts" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "artifactory-common.fullname" . }}-cleanup-scripts
  annotations:
    kustomize.toolkit.fluxcd.io/substitute: "disabled"
data:
  clear-archive.sh: |
{{ include "artifactory-common.clear-archive-script" . | indent 4 }}
  start.sh: |
{{ include "artifactory-common.cleanup-start-script" . | indent 4 }}
  stop.sh: |
{{ include "artifactory-common.cleanup-stop-script" . | indent 4 }}
{{- end -}}