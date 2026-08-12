{{- define "artifactory-common.service" -}}
{{- $values := .Values | toYaml | fromYaml -}}

{{- $serviceType := dig "service" "type" nil $values | default (dig "artifactory-common" "service" "type" nil $values) | default "ClusterIP" -}}
{{- $servicePorts := dig "service" "ports" list $values | default (dig "artifactory-common" "service" "ports" list $values) -}}
{{- $servicePort := dig "service" "port" nil $values | default (dig "artifactory-common" "service" "port" nil $values) | default 80 -}}
{{- $serviceTargetPort := dig "service" "targetPort" nil $values | default (dig "artifactory-common" "service" "targetPort" nil $values) | default "http" -}}
{{- $serviceProtocol := dig "service" "protocol" nil $values | default (dig "artifactory-common" "service" "protocol" nil $values) | default "TCP" -}}
{{- $serviceName := dig "service" "name" nil $values | default (dig "artifactory-common" "service" "name" nil $values) | default "http" -}}

apiVersion: v1
kind: Service
metadata:
  name: {{ include "artifactory-common.fullname" . }}
  labels:
    {{- include "artifactory-common.labels" . | nindent 4 }}
spec:
  type: {{ $serviceType }}
  ports:
    {{- if $servicePorts }}
    {{- toYaml $servicePorts | nindent 4 }}
    {{- else }}
    - port: {{ $servicePort }}
      targetPort: {{ $serviceTargetPort }}
      protocol: {{ $serviceProtocol }}
      name: {{ $serviceName }}
    {{- end }}
  selector:
    {{- include "artifactory-common.selectorLabels" . | nindent 4 }}
{{- end -}}