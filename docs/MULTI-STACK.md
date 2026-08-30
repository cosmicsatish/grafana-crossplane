# Multi-stack operation

Keep resource manifests stack-neutral. Select the target Grafana stack by changing the Crossplane `ProviderConfig` and environment overlay.

Recommended structure:

```text
chart/                 shared desired state
  resources/           raw provider resources
  dashboards/
  teams/

clusters/
  dev/values.yaml
  stage/values.yaml
  prod/values.yaml
```

The same resource UID/name may be used across stacks. Stack-specific Grafana IDs belong in the stack overlay or provider-controlled payload, not in Kubernetes resource names.

For LBAC, set `lbac.datasourceUid` in the target-stack values file. For aliases, map logical names to the stack-local datasource UID under `datasourceAliases`.
