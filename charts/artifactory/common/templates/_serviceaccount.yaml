{{- define "artifactory-common.serviceAccount" -}}
{{- $sa := .Values.serviceAccount | default dict -}}
{{- if hasKey $sa "create" | ternary $sa.create true -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "artifactory-common.serviceAccountName" . }}
  labels:
    {{- include "artifactory-common.labels" . | nindent 4 }}
  {{- with $sa.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ hasKey $sa "automount" | ternary $sa.automount true }}
{{- end }}
{{- end -}}