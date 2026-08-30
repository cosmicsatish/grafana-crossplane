{{/* Common helpers. Templates intentionally stay small: Helm is the only transform layer. */}}
{{- define "grafana-crossplane.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "grafana-crossplane.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: grafana-crossplane
{{- end -}}

{{- define "grafana-crossplane.providerConfigRef" -}}
providerConfigRef:
  name: {{ .Values.providerConfig.name | default "default" | quote }}
  kind: "ProviderConfig"
{{- end -}}

{{- define "grafana-crossplane.verbMap" -}}
view: View
viewer: View
read: View
reader: View
1: View
"1": View
edit: Edit
editor: Edit
write: Edit
writer: Edit
2: Edit
"2": Edit
admin: Admin
administrator: Admin
4: Admin
"4": Admin
query: Query
{{- end -}}

{{- define "grafana-crossplane.collectFiles" -}}
{{- $ctx := .ctx -}}
{{- $dirs := .dir -}}
{{- if not (kindIs "slice" $dirs) }}{{ $dirs = list $dirs }}{{ end -}}
{{- $list := list -}}
{{- range $dir := $dirs }}
  {{- range $depth := list "" "/*" "/*/*" "/*/*/*" "/*/*/*/*" "/*/*/*/*/*" -}}
    {{- range $ext := list "yaml" "yml" "json" -}}
      {{- $pattern := printf "%s%s.%s" $dir $depth $ext -}}
      {{- range $path, $_ := $ctx.Files.Glob $pattern -}}
        {{- $cs := $ctx.Files.Get $path | toString -}}
        {{- $doc := $cs | fromYaml -}}
        {{- if $doc }}{{ $list = append $list (dict "path" $path "contentStr" $cs "parsed" $doc) }}{{ end }}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end }}
items:
{{- range $item := $list }}
  - path: {{ $item.path | quote }}
    contentStr: {{ $item.contentStr | quote }}
    parsed:
      {{- toYaml $item.parsed | nindent 6 }}
{{- end }}
{{- end -}}

{{- define "grafana-crossplane.loadFiles" -}}
{{ include "grafana-crossplane.collectFiles" . }}
{{- end -}}

{{- define "grafana-crossplane.teamsList" -}}
{{- $raw := (include "grafana-crossplane.collectFiles" (dict "ctx" . "dir" "teams") | fromYaml).items | default list -}}
{{- $list := list -}}
{{- range $f := $raw }}{{- if $f.parsed.name }}{{ $list = append $list $f.parsed }}{{ end }}{{- end }}
{{- with .Values.teams }}
  {{- if kindIs "slice" . }}{{ $list = concat $list . }}
  {{- else if and (kindIs "map" .) (not (hasKey . "enabled")) }}
    {{- range $k, $v := . }}{{- if kindIs "map" $v }}{{ $list = append $list (merge (dict "name" $k) $v) }}{{ end }}{{- end }}
  {{- end }}
{{- end }}
teams:
{{- toYaml $list | nindent 2 }}
{{- end -}}

{{- define "grafana-crossplane.saList" -}}
{{- $raw := (include "grafana-crossplane.collectFiles" (dict "ctx" . "dir" "serviceaccounts") | fromYaml).items | default list -}}
{{- $list := list -}}
{{- range $f := $raw }}
  {{- if $f.parsed.serviceAccounts }}{{ $list = concat $list $f.parsed.serviceAccounts }}
  {{- else if kindIs "slice" $f.parsed }}{{ $list = concat $list $f.parsed }}
  {{- else if $f.parsed.name }}{{ $list = append $list $f.parsed }}{{ end -}}
{{- end }}
{{- with .Values.serviceAccounts }}
  {{- if kindIs "slice" . }}{{ $list = concat $list . }}
  {{- else if and (kindIs "map" .) (not (hasKey . "enabled")) }}
    {{- range $k, $v := . }}{{- if kindIs "map" $v }}{{ $list = append $list (merge (dict "name" (default $k $v.name)) $v) }}{{ end }}{{- end }}
  {{- end }}
{{- end }}
serviceAccounts:
{{- toYaml $list | nindent 2 }}
{{- end -}}

{{- define "grafana-crossplane.foldersList" -}}
{{- $raw := (include "grafana-crossplane.collectFiles" (dict "ctx" . "dir" "folders") | fromYaml).items | default list -}}
{{- $list := list -}}
{{- range $f := $raw }}
  {{- if $f.parsed.folders }}{{ $list = concat $list $f.parsed.folders }}
  {{- else if kindIs "slice" $f.parsed }}{{ $list = concat $list $f.parsed }}
  {{- else if $f.parsed.title }}{{ $list = append $list $f.parsed }}{{ end -}}
{{- end }}
{{- with .Values.folders }}
  {{- if kindIs "slice" . }}{{ $list = concat $list . }}
  {{- else if and (kindIs "map" .) (not (hasKey . "enabled")) }}
    {{- range $k, $v := . }}{{- if kindIs "map" $v }}{{ $list = append $list (merge (dict "uid" $k) $v) }}{{ end }}{{- end }}
  {{- end }}
{{- end }}
folders:
{{- toYaml $list | nindent 2 }}
{{- end -}}

{{- define "grafana-crossplane.roleRef" -}}
{{- $name := .name -}}
{{- $map := .map -}}
{{- $uids := .uids | default dict -}}
{{- if hasKey $uids $name }}{{- $uid := get $uids $name | toString | trim -}}{{- if not $uid }}{{ fail (printf "RBAC role UID override for %q is empty" $name) }}{{ end }}{{- $uid -}}{{- else if hasKey $map $name }}{{- $r := get $map $name -}}{{- $uid := "" -}}{{- if kindIs "map" $r }}{{ $uid = get $r "uid" | default "" | toString | trim }}{{ else }}{{ $uid = $r | toString | trim }}{{ end }}{{- if not $uid }}{{ fail (printf "Grafana RBAC role %q resolved to an empty UID" $name) }}{{ end }}{{- $uid -}}{{- else }}{{ fail (printf "Grafana RBAC role %q was not found in the catalog and has no rbac.roleUids override" $name) }}{{ end -}}
{{- end -}}

{{- define "grafana-crossplane.parseTtlSeconds" -}}
{{- $raw := (.secondsToLive | default .tokenExpires | default .expiresIn | default .ttl | default "" | toString | lower | trim) -}}
{{- $ttl := 31536000 -}}
{{- if $raw -}}
  {{- if regexMatch "^[0-9]+$" $raw }}{{ $ttl = int $raw
  }}{{- else if regexMatch "^[0-9]+\\s*(y|yr|yrs|year|years)$" $raw }}{{ $ttl = mul (regexFind "^[0-9]+" $raw | int) 31536000
  }}{{- else if regexMatch "^[0-9]+\\s*(m|mo|mon|month|months)$" $raw }}{{ $ttl = mul (regexFind "^[0-9]+" $raw | int) 2592000
  }}{{- else if regexMatch "^[0-9]+\\s*(min|mins|minute|minutes)$" $raw }}{{ $ttl = mul (regexFind "^[0-9]+" $raw | int) 60
  }}{{- else if regexMatch "^[0-9]+\\s*(d|day|days)$" $raw }}{{ $ttl = mul (regexFind "^[0-9]+" $raw | int) 86400
  }}{{- else if regexMatch "^[0-9]+\\s*(h|hr|hrs|hour|hours)$" $raw }}{{ $ttl = mul (regexFind "^[0-9]+" $raw | int) 3600
  }}{{- else if regexMatch "^[0-9]+\\s*(s|sec|secs|second|seconds)$" $raw }}{{ $ttl = regexFind "^[0-9]+" $raw | int
  }}{{- end }}
{{- end -}}
{{- $ttl -}}
{{- end -}}

{{- define "grafana-crossplane.parseDurationSeconds" -}}
{{- $raw := . | toString | lower | trim -}}
{{- if regexMatch "^[0-9]+$" $raw }}{{ int $raw
}}{{- else if regexMatch "^[0-9]+s$" $raw }}{{ div (regexFind "^[0-9]+" $raw | int) 1
}}{{- else if regexMatch "^[0-9]+m$" $raw }}{{ mul (regexFind "^[0-9]+" $raw | int) 60
}}{{- else if regexMatch "^[0-9]+h$" $raw }}{{ mul (regexFind "^[0-9]+" $raw | int) 3600
}}{{- else if regexMatch "^[0-9]+d$" $raw }}{{ mul (regexFind "^[0-9]+" $raw | int) 86400
}}{{- else }}60{{ end -}}
{{- end -}}

{{- define "grafana-crossplane.slugify" -}}
{{- $s := . | toString | lower | trim -}}
{{- $s = regexReplaceAll "[ _./\\\\]+" $s "-" -}}
{{- $s = regexReplaceAll "[^a-z0-9-]" $s "" -}}
{{- $s = regexReplaceAll "-{2,}" $s "-" -}}
{{- $s = $s | trimAll "-" | trunc 63 -}}
{{- $s -}}
{{- end -}}

{{- define "grafana-crossplane.folderPath" -}}
{{- $path := .path | toString -}}
{{- $segments := splitList "/" $path -}}
{{- $clean := list -}}
{{- range $i, $s := $segments }}
  {{- if and (gt $i 0) (lt $i (sub (len $segments) 1)) (ne $s "") }}{{ $clean = append $clean $s }}{{ end }}
{{- end }}
{{- join "/" $clean -}}
{{- end -}}

{{- define "grafana-crossplane.inferFolder" -}}
{{- $raw := include "grafana-crossplane.folderPath" . -}}
{{- if $raw }}{{ include "grafana-crossplane.slugify" $raw }}{{ end -}}
{{- end -}}

{{- define "grafana-crossplane.resolveFolderUid" -}}
{{- $requested := .folder | default "" | toString | trim -}}
{{- $fallback := .fallback | default "" | toString | trim -}}
{{- if not $requested -}}
  {{- if $fallback }}{{ include "grafana-crossplane.slugify" $fallback }}{{ else }}{{ "" }}{{ end -}}
{{- else -}}
  {{- $found := "" -}}
  {{- $folders := (include "grafana-crossplane.foldersList" .root | fromYaml).folders | default list -}}
  {{- range $f := $folders -}}
    {{- $uid := $f.uid | default (include "grafana-crossplane.slugify" $f.title) -}}
    {{- if or (eq $requested $uid) (eq (lower ($f.title | default "")) (lower $requested)) -}}
      {{- $found = $uid -}}
    {{- end -}}
  {{- end -}}
  {{- if $found -}}
    {{- $found -}}
  {{- else if $fallback -}}
    {{- include "grafana-crossplane.resolveFolderUid" (dict "folder" $fallback "root" .root) -}}
  {{- else -}}
    {{- include "grafana-crossplane.slugify" $requested -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "grafana-crossplane.alertMeta" -}}
metadata:
  name: {{ .name | quote }}
  annotations:
    argocd.argoproj.io/sync-wave: {{ .wave | default "2" | quote }}
  labels:
    {{- include "grafana-crossplane.labels" .root | nindent 4 }}
    {{- if .owner }}
    owner: {{ .owner | quote }}
    {{- end }}
{{- end -}}

{{- define "grafana-crossplane.renderRelativeTimeRange" -}}
relativeTimeRange:
{{- if kindIs "slice" . }}
  {{- toYaml . | nindent 2 }}
{{- else }}
  - from: {{ .from | default 0 }}
    to: {{ .to | default 0 }}
{{- end }}
{{- end -}}

{{- define "grafana-crossplane.renderRuleData" -}}
{{- $ctx := . -}}
{{- $data := $ctx.data | default list -}}
{{- $aliases := $ctx.aliases | default dict -}}
data:
{{- range $d := $data }}
  - refId: {{ $d.refId | default $d.refID | quote }}
    {{- with ($d.queryType | default $d.query_type) }}
    queryType: {{ . | quote }}
    {{- end }}
    datasourceUid: {{ include "grafana-crossplane.resolveDatasource" (dict "ref" ($d.datasourceUid | default $d.datasource_uid | default "") "aliases" $aliases) }}
    {{- with ($d.relativeTimeRange | default $d.relative_time_range) }}
    {{- include "grafana-crossplane.renderRelativeTimeRange" . | nindent 4 }}
    {{- end }}
    {{- with $d.model }}
    model: {{ if kindIs "string" . }}{{ . | quote }}{{ else }}{{ . | toJson | quote }}{{ end }}
    {{- end }}
{{- end -}}
{{- end -}}

{{- define "grafana-crossplane.renderMatchers" -}}
{{- range $m := . }}
  {{- if kindIs "slice" $m }}
- label: {{ index $m 0 | default "" | quote }}
  match: {{ index $m 1 | default "=" | quote }}
  value: {{ index $m 2 | default "" | toString | quote }}
  {{- else }}
- label: {{ $m.label | default $m.name | quote }}
  match: {{ $m.match | default $m.operator | default "=" | quote }}
  value: {{ $m.value | toString | quote }}
  {{- end }}
{{- end -}}
{{- end -}}

{{- define "grafana-crossplane.renderRoutes" -}}
{{- range $r := .routes }}
- contactPoint: {{ $r.contactPoint | default $r.contact_point | default $r.receiver | quote }}
  {{- if hasKey $r "continue" }}
  continue: {{ $r.continue }}
  {{- end }}
  {{- with ($r.groupBy | default $r.group_by) }}
  groupBy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with ($r.groupWait | default $r.group_wait) }}
  groupWait: {{ . | quote }}
  {{- end }}
  {{- with ($r.groupInterval | default $r.group_interval) }}
  groupInterval: {{ . | quote }}
  {{- end }}
  {{- with ($r.repeatInterval | default $r.repeat_interval) }}
  repeatInterval: {{ . | quote }}
  {{- end }}
  {{- with ($r.muteTimings | default $r.mute_time_intervals) }}
  muteTimings:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with ($r.activeTimings | default $r.active_time_intervals) }}
  activeTimings:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- $matchers := $r.matcher | default list }}
  {{- if not $matchers }}{{ $matchers = $r.matchers | default list }}{{ end }}
  {{- if not $matchers }}{{ $matchers = $r.object_matchers | default list }}{{ end }}
  {{- if $matchers }}
  matcher:
    {{- include "grafana-crossplane.renderMatchers" $matchers | nindent 4 }}
  {{- end }}
  {{- $sub := $r.policy | default $r.routes }}
  {{- if $sub }}
  policy:
    {{- include "grafana-crossplane.renderRoutes" (dict "routes" $sub) | nindent 4 }}
  {{- end }}
{{- end }}
{{- end -}}

{{- define "grafana-crossplane.renderContactIntegrations" -}}
{{- $cp := . -}}
{{- $native := hasKey $cp "receivers" -}}
{{- $emails := $cp.email | default list -}}{{- $slacks := $cp.slack | default list -}}{{- $pds := $cp.pagerduty | default list -}}{{- $hooks := $cp.webhook | default list -}}{{- $ops := $cp.opsgenie | default list -}}{{- $victors := $cp.victorops | default list -}}{{- $teams := $cp.teams | default list -}}{{- $discord := $cp.discord | default list -}}{{- $googlechat := $cp.googlechat | default list -}}{{- $telegram := $cp.telegram | default list -}}{{- $sns := $cp.sns | default list -}}{{- $jira := $cp.jira | default list -}}{{- $alertmanager := $cp.alertmanager | default list -}}{{- $oncall := $cp.oncall | default list -}}{{- $webex := $cp.webex | default list -}}{{- $dingding := $cp.dingding | default list -}}
{{- if $native }}
  {{- range $r := ($cp.receivers | default list) }}
    {{- $t := $r.type | toString | lower -}}{{- $s := $r.settings | default dict -}}{{- $common := dict "disableResolveMessage" (default false $r.disableResolveMessage) "uid" $r.uid -}}
    {{- with $r.settingsSecretRef }}{{ $_ := set $common "settingsSecretRef" . }}{{ end }}
    {{- if eq $t "email" }}{{ $_ := set $common "addresses" ($s.addresses | default list) }}{{ $_ := set $common "singleEmail" (default false $s.singleEmail) }}{{ $_ := set $common "message" $s.message }}{{ $_ := set $common "subject" $s.subject }}{{ $emails = append $emails $common }}
    {{- else if eq $t "slack" }}{{ $_ := set $common "url" ($s.url | default $s.endpointUrl) }}{{ $_ := set $common "title" $s.title }}{{ $_ := set $common "text" $s.text }}{{ $_ := set $common "username" $s.username }}{{ $_ := set $common "recipient" $s.recipient }}{{- with $r.urlSecretRef }}{{ $_ := set $common "urlSecretRef" . }}{{ end }}{{- with $r.tokenSecretRef }}{{ $_ := set $common "tokenSecretRef" . }}{{ end }}{{ $slacks = append $slacks $common }}
    {{- else if eq $t "pagerduty" }}{{ $_ := set $common "severity" (default "critical" $s.severity) }}{{ $_ := set $common "class" $s.class }}{{ $_ := set $common "component" $s.component }}{{ $_ := set $common "group" $s.group }}{{ $_ := set $common "summary" $s.summary }}{{- with $r.integrationKeySecretRef }}{{ $_ := set $common "integrationKeySecretRef" . }}{{ end }}{{ $pds = append $pds $common }}
    {{- else if eq $t "webhook" }}{{ $_ := set $common "url" $s.url }}{{ $_ := set $common "httpMethod" (default "POST" $s.httpMethod) }}{{ $_ := set $common "maxAlerts" $s.maxAlerts }}{{ $_ := set $common "title" $s.title }}{{ $_ := set $common "username" $s.username }}{{ $_ := set $common "message" $s.message }}{{- with $r.urlSecretRef }}{{ $_ := set $common "urlSecretRef" . }}{{ end }}{{- with $r.basicAuthPasswordSecretRef }}{{ $_ := set $common "basicAuthPasswordSecretRef" . }}{{ end }}{{- with $r.authorizationCredentialsSecretRef }}{{ $_ := set $common "authorizationCredentialsSecretRef" . }}{{ end }}{{ $hooks = append $hooks $common }}
    {{- else if eq $t "opsgenie" }}{{ $_ := set $common "message" $s.message }}{{ $_ := set $common "description" $s.description }}{{ $_ := set $common "priority" $s.priority }}{{ $_ := set $common "responders" $s.responders }}{{ $_ := set $common "tags" $s.tags }}{{- with $r.apiKeySecretRef }}{{ $_ := set $common "apiKeySecretRef" . }}{{ end }}{{ $ops = append $ops $common }}
    {{- else if eq $t "msteams" }}{{ $_ := set $common "url" $s.url }}{{ $_ := set $common "title" $s.title }}{{ $_ := set $common "message" $s.message }}{{- with $r.urlSecretRef }}{{ $_ := set $common "urlSecretRef" . }}{{ end }}{{ $teams = append $teams $common }}
    {{- else if eq $t "discord" }}{{ $_ := set $common "url" $s.url }}{{ $_ := set $common "avatarUrl" $s.avatarUrl }}{{ $_ := set $common "username" $s.username }}{{ $_ := set $common "title" $s.title }}{{ $_ := set $common "message" $s.message }}{{- with $r.urlSecretRef }}{{ $_ := set $common "urlSecretRef" . }}{{ end }}{{ $discord = append $discord $common }}
    {{- else if eq $t "googlechat" }}{{ $_ := set $common "url" $s.url }}{{ $_ := set $common "message" $s.message }}{{- with $r.urlSecretRef }}{{ $_ := set $common "urlSecretRef" . }}{{ end }}{{ $googlechat = append $googlechat $common }}
    {{- else if eq $t "telegram" }}{{ $_ := set $common "chatId" ($s.chatID | default $s.chatId) }}{{ $_ := set $common "message" $s.message }}{{ $_ := set $common "parseMode" $s.parseMode }}{{- with $r.tokenSecretRef }}{{ $_ := set $common "tokenSecretRef" . }}{{ end }}{{ $telegram = append $telegram $common }}
    {{- else if eq $t "sns" }}{{ $_ := set $common "apiUrl" $s.apiUrl }}{{ $_ := set $common "assumeRoleArn" $s.assumeRoleArn }}{{ $_ := set $common "messageFormat" $s.messageFormat }}{{ $_ := set $common "topic" $s.topic }}{{ $_ := set $common "subject" $s.subject }}{{- with $r.accessKeySecretRef }}{{ $_ := set $common "accessKeySecretRef" . }}{{ end }}{{- with $r.secretKeySecretRef }}{{ $_ := set $common "secretKeySecretRef" . }}{{ end }}{{ $sns = append $sns $common }}
    {{- else if eq $t "jira" }}{{ $_ := set $common "url" $s.url }}{{ $_ := set $common "username" $s.username }}{{ $_ := set $common "summary" $s.summary }}{{ $_ := set $common "description" $s.description }}{{ $_ := set $common "project" $s.project }}{{ $_ := set $common "issueType" $s.issueType }}{{- with $r.urlSecretRef }}{{ $_ := set $common "urlSecretRef" . }}{{ end }}{{- with $r.passwordSecretRef }}{{ $_ := set $common "passwordSecretRef" . }}{{ end }}{{ $jira = append $jira $common }}
    {{- else if eq $t "prometheus-alertmanager" }}{{ $_ := set $common "url" $s.url }}{{- with $r.urlSecretRef }}{{ $_ := set $common "urlSecretRef" . }}{{ end }}{{ $alertmanager = append $alertmanager $common }}
    {{- else if eq $t "oncall" }}{{ $_ := set $common "url" $s.url }}{{- with $r.urlSecretRef }}{{ $_ := set $common "urlSecretRef" . }}{{ end }}{{ $oncall = append $oncall $common }}
    {{- else if eq $t "webex" }}{{ $_ := set $common "apiUrl" $s.apiUrl }}{{ $_ := set $common "message" $s.message }}{{ $_ := set $common "roomId" $s.roomId }}{{ $webex = append $webex $common }}
    {{- else if eq $t "dingding" }}{{ $_ := set $common "title" $s.title }}{{ $_ := set $common "message" $s.message }}{{ $_ := set $common "messageType" $s.messageType }}{{- with $r.urlSecretRef }}{{ $_ := set $common "urlSecretRef" . }}{{ end }}{{ $dingding = append $dingding $common }}
    {{- else }}{{ fail (printf "Unsupported Grafana contact point receiver type %q in %s; use chart/resources for this receiver until provider-grafana exposes a matching block" $t $cp.name) }}{{ end }}
  {{- end }}
{{- end }}
{{- with $slacks }}slack:
{{ toYaml . | nindent 2 }}{{ end }}
{{- with $hooks }}webhook:
{{ toYaml . | nindent 2 }}{{ end }}
{{- with $pds }}pagerduty:
{{ toYaml . | nindent 2 }}{{ end }}
{{- with $emails }}email:
{{ toYaml . | nindent 2 }}{{ end }}
{{- with $ops }}opsgenie:
{{ toYaml . | nindent 2 }}{{ end }}
{{- with $victors }}victorops:
{{ toYaml . | nindent 2 }}{{ end }}
{{- with $teams }}teams:
{{ toYaml . | nindent 2 }}{{ end }}
{{- with $discord }}discord:
{{ toYaml . | nindent 2 }}{{ end }}
{{- with $googlechat }}googlechat:
{{ toYaml . | nindent 2 }}{{ end }}
{{- with $telegram }}telegram:
{{ toYaml . | nindent 2 }}{{ end }}
{{- with $sns }}sns:
{{ toYaml . | nindent 2 }}{{ end }}
{{- with $jira }}jira:
{{ toYaml . | nindent 2 }}{{ end }}
{{- with $alertmanager }}alertmanager:
{{ toYaml . | nindent 2 }}{{ end }}
{{- with $oncall }}oncall:
{{ toYaml . | nindent 2 }}{{ end }}
{{- with $webex }}webex:
{{ toYaml . | nindent 2 }}{{ end }}
{{- with $dingding }}dingding:
{{ toYaml . | nindent 2 }}{{ end }}
{{- end -}}

{{- define "grafana-crossplane.renderMuteIntervals" -}}
intervals:
  {{- toYaml (.intervals | default .time_intervals | default list) | nindent 2 }}
{{- end -}}

{{- define "grafana-crossplane.resolveDatasource" -}}
{{- $ref := .ref | default "" -}}
{{- $aliases := .aliases | default dict -}}
{{- if hasKey $aliases $ref }}{{ get (get $aliases $ref) "uid" | quote }}{{ else }}{{ $ref | quote }}{{ end -}}
{{- end -}}


{{/* Backward-compatibility aliases for grafana-admin-platform */}}
{{- define "grafana-admin-platform.name" -}}{{ include "grafana-crossplane.name" . }}{{- end -}}
{{- define "grafana-admin-platform.labels" -}}{{ include "grafana-crossplane.labels" . }}{{- end -}}
{{- define "grafana-admin-platform.providerConfigRef" -}}{{ include "grafana-crossplane.providerConfigRef" . }}{{- end -}}
{{- define "grafana-admin-platform.verbMap" -}}{{ include "grafana-crossplane.verbMap" . }}{{- end -}}
{{- define "grafana-admin-platform.collectFiles" -}}{{ include "grafana-crossplane.collectFiles" . }}{{- end -}}
{{- define "grafana-admin-platform.loadFiles" -}}{{ include "grafana-crossplane.loadFiles" . }}{{- end -}}
{{- define "grafana-admin-platform.teamsList" -}}{{ include "grafana-crossplane.teamsList" . }}{{- end -}}
{{- define "grafana-admin-platform.saList" -}}{{ include "grafana-crossplane.saList" . }}{{- end -}}
{{- define "grafana-admin-platform.foldersList" -}}{{ include "grafana-crossplane.foldersList" . }}{{- end -}}
{{- define "grafana-admin-platform.roleRef" -}}{{ include "grafana-crossplane.roleRef" . }}{{- end -}}
{{- define "grafana-admin-platform.parseTtlSeconds" -}}{{ include "grafana-crossplane.parseTtlSeconds" . }}{{- end -}}
{{- define "grafana-admin-platform.parseDurationSeconds" -}}{{ include "grafana-crossplane.parseDurationSeconds" . }}{{- end -}}
{{- define "grafana-admin-platform.slugify" -}}{{ include "grafana-crossplane.slugify" . }}{{- end -}}
{{- define "grafana-admin-platform.folderPath" -}}{{ include "grafana-crossplane.folderPath" . }}{{- end -}}
{{- define "grafana-admin-platform.inferFolder" -}}{{ include "grafana-crossplane.inferFolder" . }}{{- end -}}
{{- define "grafana-admin-platform.resolveFolderUid" -}}{{ include "grafana-crossplane.resolveFolderUid" . }}{{- end -}}
{{- define "grafana-admin-platform.alertMeta" -}}{{ include "grafana-crossplane.alertMeta" . }}{{- end -}}
{{- define "grafana-admin-platform.renderRelativeTimeRange" -}}{{ include "grafana-crossplane.renderRelativeTimeRange" . }}{{- end -}}
{{- define "grafana-admin-platform.renderRuleData" -}}{{ include "grafana-crossplane.renderRuleData" . }}{{- end -}}
{{- define "grafana-admin-platform.renderMatchers" -}}{{ include "grafana-crossplane.renderMatchers" . }}{{- end -}}
{{- define "grafana-admin-platform.renderRoutes" -}}{{ include "grafana-crossplane.renderRoutes" . }}{{- end -}}
{{- define "grafana-admin-platform.renderContactIntegrations" -}}{{ include "grafana-crossplane.renderContactIntegrations" . }}{{- end -}}
{{- define "grafana-admin-platform.renderMuteIntervals" -}}{{ include "grafana-crossplane.renderMuteIntervals" . }}{{- end -}}
{{- define "grafana-admin-platform.resolveDatasource" -}}{{ include "grafana-crossplane.resolveDatasource" . }}{{- end -}}
