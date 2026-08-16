{{- define "cronjob-common.cronjob" -}}
{{- $values := .Values | toYaml | fromYaml -}}

{{- /* Image and Command Configuration */ -}}
{{- $imageRepository := dig "image" "repository" nil $values | default (dig "cronjob-common" "image" "repository" nil $values) -}}
{{- $imageTag := dig "image" "tag" nil $values | default (dig "cronjob-common" "image" "tag" nil $values) | default "latest" -}}
{{- $imagePullPolicy := dig "image" "pullPolicy" nil $values | default (dig "cronjob-common" "image" "pullPolicy" nil $values) | default "IfNotPresent" -}}
{{- $imagePullSecrets := dig "imagePullSecrets" list $values | default (dig "cronjob-common" "imagePullSecrets" list $values) -}}
{{- $commands := dig "command" list $values | default (dig "cronjob-common" "command" list $values) | default (list "/bin/sh" "-c") -}}
{{- $script := dig "script" nil $values | default (dig "cronjob-common" "script" nil $values) -}}

{{- /* Pod Security Context */ -}}
{{- $podSecurityContext := dig "podSecurityContext" dict $values | default (dig "cronjob-common" "podSecurityContext" dict $values) | default dict | deepCopy -}}
{{- $podSecurityContextDefault := dict "fsGroup" 1001 "runAsUser" 1001 "runAsGroup" 1001 "fsGroupChangePolicy" "OnRootMismatch" -}}
{{- $podSecurityContext = mergeOverwrite $podSecurityContextDefault $podSecurityContext -}}

{{- /* Container Security Context */ -}}
{{- $containerSecurityContext := dig "securityContext" dict $values | default (dig "cronjob-common" "securityContext" dict $values) | default dict | deepCopy -}}
{{- $containerSecurityContextDefault := dict "runAsNonRoot" true "allowPrivilegeEscalation" false -}}
{{- $containerSecurityContext = mergeOverwrite $containerSecurityContextDefault $containerSecurityContext -}}

{{- /* Resources Configuration */ -}}
{{- $resources := dig "resources" dict $values | default (dig "cronjob-common" "resources" dict $values) | default dict | deepCopy -}}
{{- $resourcesDefault := dict "requests" (dict "cpu" "100m" "memory" "128Mi") "limits" (dict "cpu" "100m" "memory" "128Mi") -}}
{{- $resources = mergeOverwrite $resourcesDefault $resources -}}

{{- /* Environment Variables Configuration */ -}}
{{- $envMap := dig "envMap" dict $values | default (dig "cronjob-common" "envMap" dict $values) | default dict | deepCopy -}}
{{- $defaultEnvMap := dict -}}
{{- $envMap = mergeOverwrite $defaultEnvMap $envMap -}}
{{- $env := dig "env" list $values | default (dig "cronjob-common" "env" list $values) | default list -}}
{{- $allEnvs := list -}}
{{- range $k, $v := $envMap -}}
  {{- $allEnvs = append $allEnvs (dict "name" $k "value" ($v | toString)) -}}
{{- end -}}
{{- $allEnvs = concat $allEnvs $env -}}

{{- /* Schedule & Job-level settings */ -}}
{{- $schedule := dig "schedule" nil $values | default (dig "cronjob-common" "schedule" nil $values) | default "0 * * * *" -}}
{{- $concurrencyPolicy := dig "concurrencyPolicy" nil $values | default (dig "cronjob-common" "concurrencyPolicy" nil $values) | default "Forbid" -}}
{{- $startingDeadlineSeconds := dig "startingDeadlineSeconds" nil $values | default (dig "cronjob-common" "startingDeadlineSeconds" nil $values) | default 1800 -}}
{{- $suspend := dig "suspend" nil $values | default (dig "cronjob-common" "suspend" nil $values) | default false -}}
{{- $successfulJobsHistoryLimit := dig "successfulJobsHistoryLimit" nil $values | default (dig "cronjob-common" "successfulJobsHistoryLimit" nil $values) | default 1 -}}
{{- $failedJobsHistoryLimit := dig "failedJobsHistoryLimit" nil $values | default (dig "cronjob-common" "failedJobsHistoryLimit" nil $values) | default 3 -}}

{{- /* JobTemplate settings */ -}}
{{- $ttlSecondsAfterFinished := dig "ttlSecondsAfterFinished" nil $values | default (dig "cronjob-common" "ttlSecondsAfterFinished" nil $values) | default 3300 -}}
{{- $backoffLimit := dig "backoffLimit" nil $values | default (dig "cronjob-common" "backoffLimit" nil $values) | default 2 -}}

{{- /* Pod Template settings */ -}}
{{- $restartPolicy := dig "restartPolicy" nil $values | default (dig "cronjob-common" "restartPolicy" nil $values) | default "OnFailure" -}}
{{- $activeDeadlineSeconds := dig "activeDeadlineSeconds" nil $values | default (dig "cronjob-common" "activeDeadlineSeconds" nil $values) | default 3600 -}}
{{- $terminationGracePeriodSeconds := dig "terminationGracePeriodSeconds" nil $values | default (dig "cronjob-common" "terminationGracePeriodSeconds" nil $values) | default 30 -}}
{{- $serviceAccountName := include "cronjob-common.serviceAccountName" . -}}
{{- $nodeSelector := dig "nodeSelector" dict $values | default (dig "cronjob-common" "nodeSelector" dict $values) -}}
{{- $affinity := dig "affinity" dict $values | default (dig "cronjob-common" "affinity" dict $values) -}}
{{- $tolerations := dig "tolerations" list $values | default (dig "cronjob-common" "tolerations" list $values) -}}

apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ include "cronjob-common.fullname" . }}
  labels:
    {{- include "cronjob-common.labels" . | nindent 4 }}
spec:
  schedule: {{ $schedule | quote }}
  concurrencyPolicy: {{ $concurrencyPolicy }}
  startingDeadlineSeconds: {{ $startingDeadlineSeconds }}
  suspend: {{ $suspend }}
  successfulJobsHistoryLimit: {{ $successfulJobsHistoryLimit }}
  failedJobsHistoryLimit: {{ $failedJobsHistoryLimit }}
  jobTemplate:
    spec:
      ttlSecondsAfterFinished: {{ $ttlSecondsAfterFinished }}
      backoffLimit: {{ $backoffLimit }}
      template:
        spec:
          restartPolicy: {{ $restartPolicy }}
          activeDeadlineSeconds: {{ $activeDeadlineSeconds }}
          terminationGracePeriodSeconds: {{ $terminationGracePeriodSeconds }}
          serviceAccountName: {{ $serviceAccountName }}
          {{- with $imagePullSecrets }}
          imagePullSecrets:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          securityContext:
            {{- toYaml $podSecurityContext | nindent 12 }}
          containers:
            - name: {{ .Chart.Name }}
              securityContext:
                {{- toYaml $containerSecurityContext | nindent 16 }}
              image: "{{ $imageRepository }}:{{ $imageTag }}"
              imagePullPolicy: {{ $imagePullPolicy }}
              resources:
                {{- toYaml $resources | nindent 16 }}
              env:
                {{- toYaml $allEnvs | nindent 16 }}
              command:
                {{- toYaml $commands | nindent 16 }}
              args:
                - {{ $script | quote }}
{{- end -}}
