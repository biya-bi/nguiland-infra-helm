{{- define "artifactory-common.data" -}}
{{- $persistence := .Values.persistence | default dict -}}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "artifactory-common.fullname" . }}-data
  labels:
    {{- include "artifactory-common.labels" . | nindent 4 }}
spec:
  accessModes:
    - ReadWriteOnce
  {{- if $persistence.storageClass }}
  storageClassName: {{ $persistence.storageClass | quote }}
  {{- end }}
  resources:
    requests:
      storage: {{ $persistence.size | default "10Gi" | quote }}
{{- end -}}
