{{/* Shared helpers for the small official-resource surface. */}}

{{- define "grafana-crossplane.managedSpec" -}}
managementPolicies:
  - Observe
  - Create
  - Update
  - Delete
{{- end -}}

{{- define "grafana-crossplane.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: grafana-crossplane
{{- end -}}

{{- define "grafana-crossplane.providerConfigRef" -}}
providerConfigRef:
  name: {{ .Values.providerConfig.name | default "default" | quote }}
  kind: ProviderConfig
{{- end -}}

{{- define "grafana-crossplane.collectFiles" -}}
{{- $ctx := .ctx -}}
{{- $dir := .dir -}}
{{- $items := list -}}
{{- range $depth := list "" "/*" "/*/*" "/*/*/*" "/*/*/*/*" "/*/*/*/*/*" -}}
  {{- range $ext := list "yaml" "yml" "json" -}}
    {{- range $path, $_ := $ctx.Files.Glob (printf "%s%s.%s" $dir $depth $ext) -}}
      {{- $doc := $ctx.Files.Get $path | fromYaml -}}
      {{- if $doc -}}
        {{- $items = append $items (dict "path" $path "parsed" $doc) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
items:
{{- range $item := $items }}
  - path: {{ $item.path | quote }}
    parsed:
      {{- toYaml $item.parsed | nindent 6 }}
{{- end -}}
{{- end -}}

{{- define "grafana-crossplane.foldersList" -}}
{{- $files := (include "grafana-crossplane.collectFiles" (dict "ctx" . "dir" "folders") | fromYaml).items | default list -}}
{{- $items := list -}}
{{- $knownTitles := dict -}}
{{- range $f := $files -}}
  {{- $parsedList := list -}}
  {{- if $f.parsed.folders -}}
    {{- $parsedList = $f.parsed.folders -}}
  {{- else if kindIs "slice" $f.parsed -}}
    {{- $parsedList = $f.parsed -}}
  {{- else if $f.parsed.title -}}
    {{- $parsedList = append $parsedList $f.parsed -}}
  {{- end -}}
  {{- range $item := $parsedList -}}
    {{- $items = append $items $item -}}
    {{- if $item.title }}{{ $_ := set $knownTitles (lower $item.title) true }}{{ end -}}
    {{- if $item.uid }}{{ $_ := set $knownTitles (lower $item.uid) true }}{{ end -}}
  {{- end -}}
{{- end -}}
{{/* Auto-discover folders from dashboards subdirectories if not explicitly defined */}}
{{- $dashFiles := (include "grafana-crossplane.collectFiles" (dict "ctx" . "dir" "dashboards") | fromYaml).items | default list -}}
{{- range $df := $dashFiles -}}
  {{- $dirName := include "grafana-crossplane.folderPath" (dict "path" $df.path) -}}
  {{- if and $dirName (not (hasKey $knownTitles (lower $dirName))) -}}
    {{- $_ := set $knownTitles (lower $dirName) true -}}
    {{- $items = append $items (dict "title" $dirName "uid" (include "grafana-crossplane.slugify" $dirName)) -}}
  {{- end -}}
{{- end -}}
folders:
{{- toYaml $items | nindent 2 }}
{{- end -}}

{{- define "grafana-crossplane.teamsList" -}}
{{- $files := (include "grafana-crossplane.collectFiles" (dict "ctx" . "dir" "teams") | fromYaml).items | default list -}}
{{- $items := list -}}
{{- range $f := $files -}}
  {{- if $f.parsed.teams -}}
    {{- $items = concat $items $f.parsed.teams -}}
  {{- else if kindIs "slice" $f.parsed -}}
    {{- $items = concat $items $f.parsed -}}
  {{- else if $f.parsed.name -}}
    {{- $items = append $items $f.parsed -}}
  {{- end -}}
{{- end -}}
teams:
{{- toYaml $items | nindent 2 }}
{{- end -}}

{{- define "grafana-crossplane.saList" -}}
{{- $files := (include "grafana-crossplane.collectFiles" (dict "ctx" . "dir" "serviceaccounts") | fromYaml).items | default list -}}
{{- $items := list -}}
{{- range $f := $files -}}
  {{- if $f.parsed.serviceAccounts -}}
    {{- $items = concat $items $f.parsed.serviceAccounts -}}
  {{- else if kindIs "slice" $f.parsed -}}
    {{- $items = concat $items $f.parsed -}}
  {{- else if $f.parsed.name -}}
    {{- $items = append $items $f.parsed -}}
  {{- end -}}
{{- end -}}
serviceAccounts:
{{- toYaml $items | nindent 2 }}
{{- end -}}

{{- define "grafana-crossplane.slugify" -}}
{{- $s := . | toString | lower | trim -}}
{{- $s = regexReplaceAll "[ _./\\\\]+" $s "-" -}}
{{- $s = regexReplaceAll "[^a-z0-9-]" $s "" -}}
{{- $s = regexReplaceAll "-{2,}" $s "-" -}}
{{- trimAll "-" $s | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Use a stable hash only when truncation is required, preventing name collisions. */}}

{{- define "grafana-crossplane.resourceName" -}}
{{- $raw := . | toString | lower | trim -}}
{{- $s := regexReplaceAll "[ _./\\\\]+" $raw "-" -}}
{{- $s = regexReplaceAll "[^a-z0-9-]" $s "" -}}
{{- $s = regexReplaceAll "-{2,}" $s "-" -}}
{{- $s = trimAll "-" $s -}}
{{- if le (len $s) 63 -}}
{{- $s -}}
{{- else -}}
{{- printf "%s-%s" (trunc 54 $s | trimSuffix "-") (sha256sum $s | trunc 8) -}}
{{- end -}}
{{- end -}}

{{- define "grafana-crossplane.folderPath" -}}
{{- $path := .path | toString -}}
{{- $segments := splitList "/" $path -}}
{{- $clean := list -}}
{{- range $i, $segment := $segments -}}
  {{- if and (gt $i 0) (lt $i (sub (len $segments) 1)) $segment -}}
    {{- $clean = append $clean $segment -}}
  {{- end -}}
{{- end -}}
{{- join "/" $clean -}}
{{- end -}}

{{- define "grafana-crossplane.resolveFolderUid" -}}
{{- $requested := .folder | default "" | toString | trim -}}
{{- $fallback := .fallback | default "" | toString | trim -}}
{{- if not $requested -}}
  {{- if $fallback }}{{ include "grafana-crossplane.slugify" $fallback }}{{ end -}}
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

{{- define "grafana-crossplane.parseTtlSeconds" -}}
{{- $raw := (.secondsToLive | default .tokenExpires | default .expiresIn | default .ttl | default "" | toString | lower | trim) -}}
{{- if not $raw }}{{ fail "service-account token lifetime is required" }}{{- else if regexMatch "^[0-9]+$" $raw }}{{ int $raw
}}{{- else if regexMatch "^[0-9]+\\s*(y|yr|yrs|year|years)$" $raw }}{{ mul (regexFind "^[0-9]+" $raw | int) 31536000
}}{{- else if regexMatch "^[0-9]+\\s*(m|mo|mon|month|months)$" $raw }}{{ mul (regexFind "^[0-9]+" $raw | int) 2592000
}}{{- else if regexMatch "^[0-9]+\\s*(min|mins|minute|minutes)$" $raw }}{{ mul (regexFind "^[0-9]+" $raw | int) 60
}}{{- else if regexMatch "^[0-9]+\\s*(d|day|days)$" $raw }}{{ mul (regexFind "^[0-9]+" $raw | int) 86400
}}{{- else if regexMatch "^[0-9]+\\s*(h|hr|hrs|hour|hours)$" $raw }}{{ mul (regexFind "^[0-9]+" $raw | int) 3600
}}{{- else if regexMatch "^[0-9]+\\s*(s|sec|secs|second|seconds)$" $raw }}{{ regexFind "^[0-9]+" $raw | int
}}{{- else }}{{ fail (printf "Unsupported service-account token lifetime %q" $raw) }}{{- end -}}
{{- end -}}

{{- define "grafana-crossplane.alertMeta" -}}
metadata:
  name: {{ .name | quote }}
  annotations:
    argocd.argoproj.io/sync-wave: {{ .wave | default "2" | quote }}
  labels:
    {{- include "grafana-crossplane.labels" .root | nindent 4 }}
    {{- with .owner }}
    owner: {{ . | quote }}
    {{- end }}
{{- end -}}


{{- define "grafana-crossplane.roleMaps" -}}
{{- $fixedPath := .Values.rbac.roleCatalog.fixedPath | default "catalog/fixed-roles.yaml" -}}
{{- $pluginPath := .Values.rbac.roleCatalog.pluginPath | default "catalog/stacks/default/plugin-roles.yaml" -}}
{{- $presetPath := .Values.rbac.roleCatalog.presetPath | default "catalog/role-presets.yaml" -}}
{{- $fixedMap := dict -}}{{- $pluginMap := dict -}}{{- $presets := dict -}}
{{- $fc := .Files.Get $fixedPath -}}{{- if not $fc }}{{ fail (printf "fixed role catalog %s not found" $fixedPath) }}{{ end -}}
{{- range $r := (fromYamlArray $fc) }}{{- if and $r.name $r.uid }}{{ $_ := set $fixedMap $r.name $r.uid }}{{ end }}{{- end -}}
{{- $pc := .Files.Get $pluginPath -}}{{- if not $pc }}{{ fail (printf "plugin role catalog %s not found; set rbac.roleCatalog.pluginPath for this Grafana stack" $pluginPath) }}{{ end -}}
{{- range $r := (fromYamlArray $pc) }}{{- if and $r.name $r.uid }}{{ $_ := set $pluginMap $r.name $r.uid }}{{ end }}{{- end -}}
{{- $prc := .Files.Get $presetPath -}}{{- if $prc }}{{ $presets = fromYaml $prc | default dict }}{{ end -}}
fixed: {{ toJson $fixedMap }}
plugin: {{ toJson $pluginMap }}
presets: {{ toJson $presets }}
{{- end -}}

{{- define "grafana-crossplane.resolveRoleUid" -}}
{{- $maps := (include "grafana-crossplane.roleMaps" .root | fromYaml) -}}
{{- $name := .name | toString | trim -}}
{{- if hasKey $maps.fixed $name }}{{ get $maps.fixed $name }}
{{- else if hasKey $maps.plugin $name }}{{ get $maps.plugin $name }}
{{- else }}{{ fail (printf "RBAC role %q is not present in the configured fixed/plugin role catalog" $name) }}{{- end -}}
{{- end -}}

{{- define "grafana-crossplane.expandRoleNames" -}}
{{- $root := .root -}}
{{- $items := list -}}
{{- range ($.presets | default list) }}
  {{- $p := . | toString -}}
  {{- $presetMap := ((include "grafana-crossplane.roleMaps" $root | fromYaml).presets | default dict) -}}
  {{- if hasKey $presetMap $p }}{{ $items = concat $items (get $presetMap $p) }}{{ else }}{{ fail (printf "Unknown RBAC preset %q" $p) }}{{ end -}}
{{- end -}}
{{- range ($.roles | default list) }}{{ $items = append $items (. | toString) }}{{- end -}}
{{- range ($.fixedRoles | default list) }}{{ $items = append $items (. | toString) }}{{- end -}}
{{- uniq $items | toYaml -}}
{{- end -}}

{{- define "grafana-crossplane.roleAssignmentsMap" -}}
{{- $root := . -}}
{{- $roleMap := dict -}}
{{- $teams := (include "grafana-crossplane.teamsList" $root | fromYaml).teams | default list -}}
{{- $sas := (include "grafana-crossplane.saList" $root | fromYaml).serviceAccounts | default list -}}
{{- $presetMap := ((include "grafana-crossplane.roleMaps" $root | fromYaml).presets | default dict) -}}
{{- range $t := $teams -}}
  {{- $tSlug := include "grafana-crossplane.resourceName" ($t.resourceName | default $t.slug | default $t.name) -}}
  {{- $roles := list -}}
  {{- with $t.preset }}{{ range (get $presetMap . | default list) }}{{ $roles = append $roles . }}{{ end }}{{ end -}}
  {{- range ($t.presets | default list) }}{{ range (get $presetMap . | default list) }}{{ $roles = append $roles . }}{{ end }}{{ end -}}
  {{- range ($t.roles | default list) }}{{ $roles = append $roles . }}{{ end -}}
  {{- range ($t.fixedRoles | default list) }}{{ $roles = append $roles . }}{{ end -}}
  {{- range $r := (uniq $roles) -}}
    {{- if not (hasKey $roleMap $r) -}}
      {{- $_ := set $roleMap $r (dict "teams" list "serviceAccounts" list) -}}
    {{- end -}}
    {{- $entry := get $roleMap $r -}}
    {{- $_ := set $entry "teams" (append $entry.teams $tSlug) -}}
  {{- end -}}
{{- end -}}
{{- range $sa := $sas -}}
  {{- $saSlug := include "grafana-crossplane.resourceName" ($sa.resourceName | default $sa.name) -}}
  {{- $roles := list -}}
  {{- with $sa.preset }}{{ range (get $presetMap . | default list) }}{{ $roles = append $roles . }}{{ end }}{{ end -}}
  {{- range ($sa.presets | default list) }}{{ range (get $presetMap . | default list) }}{{ $roles = append $roles . }}{{ end }}{{ end -}}
  {{- range ($sa.roles | default list) }}{{ $roles = append $roles . }}{{ end -}}
  {{- range ($sa.fixedRoles | default list) }}{{ $roles = append $roles . }}{{ end -}}
  {{- range $r := (uniq $roles) -}}
    {{- if not (hasKey $roleMap $r) -}}
      {{- $_ := set $roleMap $r (dict "teams" list "serviceAccounts" list) -}}
    {{- end -}}
    {{- $entry := get $roleMap $r -}}
    {{- $_ := set $entry "serviceAccounts" (append $entry.serviceAccounts $saSlug) -}}
  {{- end -}}
{{- end -}}
{{- toYaml $roleMap -}}
{{- end -}}

{{- define "grafana-crossplane.folderPermissionsMap" -}}
{{- $root := . -}}
{{- $fMap := dict -}}
{{- $folders := (include "grafana-crossplane.foldersList" $root | fromYaml).folders | default list -}}
{{- range $f := $folders -}}
  {{- $uid := $f.uid | default (include "grafana-crossplane.slugify" $f.title) -}}
  {{- $perms := list -}}
  {{- range $p := ($f.permissions | default list) -}}
    {{- if $p.role -}}
      {{- $perm := $p.permission | default "View" | toString | title -}}
      {{- $perms = append $perms (dict "role" ($p.role | toString | title) "permission" $perm) -}}
    {{- end -}}
  {{- end -}}
  {{- if $perms -}}
    {{- $_ := set $fMap $uid $perms -}}
  {{- end -}}
{{- end -}}
{{- $teams := (include "grafana-crossplane.teamsList" $root | fromYaml).teams | default list -}}
{{- range $t := $teams -}}
  {{- $tSlug := include "grafana-crossplane.resourceName" ($t.resourceName | default $t.slug | default $t.name) -}}
  {{- range $fp := ($t.folderPermissions | default list) -}}
    {{- $fUid := include "grafana-crossplane.resolveFolderUid" (dict "folder" $fp.folder "root" $root) -}}
    {{- $perm := $fp.permission | default "View" | toString | title -}}
    {{- if not (hasKey $fMap $fUid) -}}
      {{- $_ := set $fMap $fUid list -}}
    {{- end -}}
    {{- $cur := get $fMap $fUid -}}
    {{- $_ := set $fMap $fUid (append $cur (dict "teamRef" (dict "name" $tSlug) "permission" $perm)) -}}
  {{- end -}}
{{- end -}}
{{- toYaml $fMap -}}
{{- end -}}

