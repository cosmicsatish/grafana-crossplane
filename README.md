# Grafana Crossplane GitOps

Declarative Grafana Cloud management with Git → Argo CD → Helm → Crossplane → provider-grafana. The repository intentionally uses only official provider-managed resources and no custom controllers, jobs, scripts, Terraform, or runtime role discovery.

## Managed resources

- `Dashboard`, `DashboardV2`: one dashboard per managed resource.
- `Folder`: only explicitly declared folders; deletion is Orphan and non-empty deletion is protected.
- `FolderPermissionItem`: one folder permission item at a time.
- `Team`, `TeamExternalGroup`: team identity plus optional external-group set; team deletion is Orphan by default.
- `ServiceAccount`, `ServiceAccountToken`: explicit accounts and tokens; account deletion is Orphan and tokens are independent resources.
- `ServiceAccountPermissionItem`: one management permission at a time.
- `RoleAssignmentItem`: one fixed/plugin RBAC assignment at a time for a Team or Service Account.

The repository does not manage datasources, alerting resources, LBAC, SLO, Synthetic Monitoring, whole-set permission/RBAC resources, custom roles, or UID lookup jobs.

## RBAC and multi-stack role portability

Teams and Service Accounts refer to Grafana **role names**, never role UIDs. `preset`/`presets` are expanded by Helm into individual `RoleAssignmentItem` resources.

Built-in fixed-role UIDs live in `chart/catalog/fixed-roles.yaml`. Grafana documents these fixed UUIDs as provisioning identifiers, with availability caveats for older instances. citeturn970918search0turn646263view0

Plugin roles are stack-specific. Their UIDs live only in `chart/catalog/stacks/<stack>/plugin-roles.yaml`; choose the file through `rbac.roleCatalog.pluginPath`. The same Team/ServiceAccount definitions can therefore be reused across stacks while each stack resolves its own plugin-role UIDs. Grafana's RBAC API exposes role names and UIDs, but provider-grafana does not provide a native list/data-source lookup that could be wired into `RoleAssignmentItem`, so no script/job is used. citeturn970918search4turn575153search0

Example:

```yaml
name: SRE
preset: sre
roles:
  - plugins:grafana-kowalski-app:frontend-observability-viewer
```

For a new stack, copy the default plugin catalog to a stack-specific file and update only the UID values. Do not place plugin UIDs in Team or Service Account files.

## Ownership rules

Each Crossplane managed resource is the ownership boundary. Omitted Git objects are not discovered or swept from Grafana. Use item resources for permissions and role assignments. Do not use whole-set APIs for resources that contain unrelated children. Native Grafana state that is not represented by one of these resources remains unmanaged.

## Layout

```text
chart/
  dashboards/
  folders/
  teams/
  serviceaccounts/
  catalog/
    fixed-roles.yaml
    role-presets.yaml
    stacks/<stack>/plugin-roles.yaml
  templates/
deploy/argocd/
deploy/crossplane/
examples/
```

Credentials remain outside Git and are supplied through the Crossplane `ProviderConfig`.

## Crossplane v2 lifecycle policy

This chart targets Crossplane v2 namespaced managed resources. It uses `spec.managementPolicies` only; the legacy `spec.deletionPolicy` field is intentionally not rendered.

Resources that are safe to delete from Grafana when their individual Git object is removed include dashboards, explicit folder-permission items, service-account tokens, service-account permission items, and individual RBAC role assignments. Parent resources with potentially broad secondary effects (folders, teams, service accounts, and TeamExternalGroup mappings) omit `Delete` from `managementPolicies` by default, so deleting their Git object does not delete the external Grafana object.

Crossplane v2 removes `deletionPolicy` from namespaced managed resources and uses `managementPolicies` to control observe/create/update/delete behavior. The provider must support management policies for this to take effect.
