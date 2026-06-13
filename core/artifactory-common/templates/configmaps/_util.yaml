{{- define "artifactory-common.util-scripts" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "artifactory-common.fullname" . }}-util-scripts
  annotations:
    kustomize.toolkit.fluxcd.io/substitute: "disabled"
data:
  artifactory.sh: |
{{ include "artifactory-common.artifactory-script" . | indent 4 }}
  colors.sh: |
{{ include "artifactory-common.colors-script" . | indent 4 }}
  logger.sh: |
{{ include "artifactory-common.logger-script" . | indent 4 }}
{{- end -}}