# Repository directory conventions

The chart is intentionally Git-first. Put desired state in the resource directory that matches its Grafana feature:

- `teams/` — teams and optional external group mappings
- `folders/` — explicit folder hierarchy and permissions
- `serviceaccounts/` — service accounts and token definitions
- `datasources/` — datasource declarations and datasource permissions
- `dashboards/<Folder>/` — Grafana dashboard JSON exports
- `alert-rules/<Folder>/` — alert rule exports or repository `ruleGroups` YAML
- `contact-points/<Folder>/`
- `notification-policies/<Folder>/`
- `mute-timings/<Folder>/`
- `message-templates/<Folder>/`
- `slos/<Folder>/`
- `synthetic-monitoring/<Folder>/`
- `resources/` — complete raw Crossplane manifests for provider resources without a convenience template
- `catalog/` — optional stack-derived catalogs maintained outside the core deployment path

Folder names are metadata in the Git layout; they do not automatically rewrite Grafana folder UIDs. Kubernetes resource names are slugified, while Grafana payload UIDs are preserved.
