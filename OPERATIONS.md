# Operations and safety

## Prerequisites

Install Kubernetes, Crossplane, Argo CD and Helm 3+. Install the pinned official Grafana provider `xpkg.upbound.io/grafana/provider-grafana:v2.14.0`. Create the provider credential Secret outside Git.

## Daily workflow

1. Add or modify one managed resource file under `chart/`.
2. For RBAC, use role names or presets; never hard-code plugin-role UIDs in Team/Service Account manifests.
3. Commit and let Argo CD render the chart.
4. Crossplane reconciles only the rendered managed resources.

## Safe ownership boundaries

`Dashboard`/`DashboardV2` manage one dashboard. `FolderPermissionItem`, `ServiceAccountPermissionItem`, and `RoleAssignmentItem` each represent one independent relationship. Removing one item removes only that relationship.

Folders, Teams and Service Accounts are Orphan-on-delete by default because deleting them can have secondary effects. `TeamExternalGroup` is set-valued for one Team; deletion is Orphan by default. Only opt into external-group deletion when Git is the authoritative source for that Team's entire external-group mapping.

Do not add whole-set resources for permissions, alerting trees or role assignment collections. Those APIs can replace relationships that are not represented in Git.

## RBAC catalog

Built-in fixed roles are centralized in `chart/catalog/fixed-roles.yaml`. Plugin role UIDs are stack-local and belong in `chart/catalog/stacks/<stack>/plugin-roles.yaml`. Set the selected catalog with `rbac.roleCatalog.pluginPath`. Team and Service Account files use role names/presets only. Grafana documents fixed-role UUIDs for provisioning and notes that older Grafana instances may not expose them. citeturn970918search0

`RoleAssignmentItem` is deliberately used instead of the provider's whole-set `RoleAssignment`; the provider documents `RoleAssignmentItem` as managing a single assignment and conflicting with the whole-set resource. citeturn982509search0turn982509search2

## Multi-stack

Use the same chart and resource files for all stacks. Only change the ProviderConfig and the plugin-role catalog path. Fixed role names remain stable logical inputs; plugin roles are resolved from the selected per-stack catalog. Grafana's RBAC API returns the current role names and UIDs, but provider-grafana has no native list data source for wiring that discovery into a managed resource, so this repository keeps discovery out of the runtime and makes the stack catalog explicit. citeturn970918search4turn575153search0

## Troubleshooting

```bash
argocd app get grafana-crossplane
kubectl -n crossplane-system get dashboard,dashboardv2,folder,folderpermissionitem,team,teamexternalgroup,serviceaccount,serviceaccounttoken,serviceaccountpermissionitem,roleassignmentitem
kubectl -n crossplane-system describe <kind> <name>
```


### Crossplane v2 lifecycle policy

The chart emits only `spec.managementPolicies` for namespaced Grafana managed resources. Do not add `deletionPolicy`; it is not part of the Crossplane v2 namespaced managed-resource API.

- `Observe, Create, Update, Delete`: full lifecycle ownership of that individual external object.
- `Observe, Create, Update`: manage and observe the external object, but orphan it when the Kubernetes managed resource is removed.
- `Observe`: import/observe only; Crossplane does not create, update, or delete the external object.

Keep parent resources such as folders, teams, service accounts, and TeamExternalGroup mappings non-deleting by default. Use deletion only when Git is explicitly authoritative for the complete parent object or set.
