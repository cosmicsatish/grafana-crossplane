# Raw Crossplane resources

Use this directory for any provider-grafana resource that does not have a convenience template yet. Commit complete Crossplane managed resources with `apiVersion`, `kind`, `metadata`, and `spec`.

Use the current namespaced API groups from the provider version you install. The repository is written for provider-grafana v2.x, for example:

- `oss.grafana.m.crossplane.io/v1alpha1`
- `enterprise.grafana.m.crossplane.io/v1alpha1`
- `alerting.grafana.m.crossplane.io/v1alpha1`
- `cloud.grafana.m.crossplane.io/v1alpha1`
- `slo.grafana.m.crossplane.io/v1alpha1`
- `sm.grafana.m.crossplane.io/v1alpha1`

Do not put Kubernetes `status`, connection credentials, or generated metadata in exported manifests.
