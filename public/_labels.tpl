{{- define "mychart.labels" }}
    labels:
      generated: helm
      managed: crossplane
      name: {{ .Chart.Name  }}
      project: {{ .Values.project  }}
      type: {{ .Values.type  }}
      date: {{ now | htmlDate }}
{{- end }}
