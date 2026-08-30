# Resource coverage

The chart has convenience templates for the following provider-grafana resource families:

| Family | Current API group | Convenience support |
|---|---|---|
| Team | `oss.grafana.m.crossplane.io` | Yes |
| Folder / FolderPermission | `oss.grafana.m.crossplane.io` | Yes |
| ServiceAccount / Token | `oss.grafana.m.crossplane.io` | Yes |
| Dashboard / DashboardV2 | `oss.grafana.m.crossplane.io` | Yes |
| DataSource | `oss.grafana.m.crossplane.io` | Yes |
| DataSourcePermission / LBAC | `enterprise.grafana.m.crossplane.io` | Yes |
| RoleAssignment / external groups | `enterprise.grafana.m.crossplane.io` | Yes |
| RuleGroup / ContactPoint / NotificationPolicy / MuteTiming / MessageTemplate | `alerting.grafana.m.crossplane.io` | Yes |
| SLO | `slo.grafana.m.crossplane.io` | Yes |
| Synthetic Monitoring Check | `sm.grafana.m.crossplane.io` | Yes |
| Cloud AccessPolicy | `cloud.grafana.m.crossplane.io` | Raw resource path |

The raw resource path is intentional. New provider CRDs can be adopted without changing the chart templates.
