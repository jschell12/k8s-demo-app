{{- define "k8s-demo-app-chart.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "k8s-demo-app-chart.fullname" -}}
{{- include "k8s-demo-app-chart.name" . }}-{{ .Release.Name }}
{{- end -}} 

{{- define "k8s-demo-app-chart.labels" -}}
helm.sh/chart: {{ include "k8s-demo-app-chart.name" . }}-{{ .Chart.Version }}
{{- end -}}