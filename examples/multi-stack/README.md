# Multi-stack example

Keep `chart/` resource files shared and select a target `ProviderConfig` from an environment overlay.

A minimal overlay:

```yaml
providerConfig:
  name: grafana-prod

grafana:
  stackName: production
  url: https://prod.example.grafana.net

lbac:
  enabled: false
```

A second stack can use the same Git resources with another overlay and ProviderConfig. The resources themselves should not contain bearer tokens or cluster-specific Kubernetes names.
