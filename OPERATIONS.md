# Operations & Safety Guide

This operational manual describes daily operations, safety boundaries, troubleshooting procedures, and recovery workflows for the Grafana Crossplane GitOps platform.

---

## 1. Daily GitOps Workflow

1. **Add or Modify Manifests**:
   - Folders: Edit `chart/folders/folders.yaml`.
   - Teams: Add or edit `chart/teams/<team-name>.yaml`.
   - Service Accounts & Tokens: Edit `chart/serviceaccounts/serviceaccounts.yaml`.
   - Dashboards: Drop exported JSON into `chart/dashboards/<Folder>/<dashboard>.json`.
2. **Local Validation**:
   ```bash
   make validate
   ```
   *Always run `make validate` before pushing to verify template expansion, role name references, and YAML schemas.*
3. **Commit & Push**:
   ```bash
   git add -A
   git commit -m "feat(observability): add alerting team and platform dashboards"
   git push origin main
   ```
4. **Automated Reconciliation**:
   - Argo CD detects the Git commit.
   - Evaluates sync-waves in sequence:
     - **Wave 0**: Folders, Teams, Service Accounts
     - **Wave 1**: Team External Groups, Folder Permissions, Role Assignments, Tokens
     - **Wave 2**: Dashboards & DashboardsV2
   - Crossplane reconciles with Grafana Cloud under enforced rate limits.

---

## 2. Safe Ownership & Deletion Boundaries

### Parent Resource Safety (Strict Orphan-on-Delete)
- **`Folder`**, **`Team`**, and **`ServiceAccount`** resources are configured with:
  ```yaml
  managementPolicies:
    - Observe
    - Create
    - Update
  ```
- **Operational Effect**: Removing a folder, team, or service account manifest from Git deletes the Kubernetes CR but **orphans** the external object in Grafana Cloud.
- **Why**: Deleting a parent resource in Grafana cascades destructively (deleting all dashboards in a folder, breaking team alert routing, or invalidating active API tokens).

### Granular Leaf Deletion
- **`Dashboard`** and **`ServiceAccountToken`** resources are configured with `Delete` in `managementPolicies`.
- **Operational Effect**: Removing an individual dashboard or token manifest from Git safely deletes that specific object from Grafana Cloud without affecting surrounding resources.

### Folder Empty-Check Protection
- Folders are strictly protected by default (`preventDestroyIfNotEmpty: true` hardcoded). Grafana Cloud will reject deletion if any unmanaged dashboard, alert, or subfolder exists within it.

---

## 3. CLI Management with Short Names

Use the configured short names to inspect and operate on your stack quickly:

```bash
# Check all resources across your stack
kubectl get gdash,gfolders,gteams,gsa,gfp,gra,gteg,gdspi,glbac -n crossplane-system

# Check status of folders
kubectl get gfolders -n crossplane-system

# Check status of teams
kubectl get gteams -n crossplane-system

# Check LBAC rules and datasource permissions
kubectl get glbac,gdspi -n crossplane-system


# Check status of folders
kubectl get gfolders -n crossplane-system

# Check status of teams
kubectl get gteams -n crossplane-system

# Inspect a specific role assignment
kubectl describe gra role-fixedalertingadmin -n crossplane-system

# Check generated Service Account secrets
kubectl get secrets -n crossplane-system -l app.kubernetes.io/part-of=grafana-crossplane
```

---

## 4. Runbooks for Common Tasks

### Runbook A: Rotating an API Token
1. In `chart/serviceaccounts/serviceaccounts.yaml`, add a new token entry to `tokens:` with a new name and Secret name:
   ```yaml
   tokens:
     - name: deployer-token-v2
       secretName: deployer-grafana-token-v2
       secondsToLive: "90d"
   ```
2. Run `make validate`, commit, and push.
3. Once the new Kubernetes Secret is generated, update your consuming application (e.g. CI pipeline) with the new token.
4. Remove the old token entry from `tokens:`. Commit and push. Crossplane will delete the old token from Grafana Cloud.

### Runbook B: Re-syncing Role Catalogs after a Grafana Upgrade
When Grafana Cloud upgrades or new plugins are installed, new `fixed:*` and `plugins:*` roles may become available:
1. Export credentials:
   ```bash
   export GRAFANA_URL="https://<your-org>.grafana.net"
   export GRAFANA_TOKEN="glsa_..."
   ```
2. Run the sync target:
   ```bash
   make sync-roles
   ```
3. Commit and push the updated `chart/catalog/` files to Git.

### Runbook C: Recovering an Orphaned Resource into Git
If a resource was removed from Git, orphaned in Grafana, and you now want to bring it back under GitOps control:
1. Re-add the YAML definition in `chart/` using the original `uid` (for folders/dashboards) or `name` (for teams/service accounts).
2. Commit and push.
3. Crossplane will observe the existing Grafana object and adopt it seamlessly without recreating or modifying its internal ID.

### Runbook D: Onboarding Existing LBAC Rules on Day 0
When bringing an existing Grafana stack under GitOps without wiping out pre-existing LBAC rules:
1. Run the one-time import command:
   ```bash
   make import-lbac
   ```
2. Inspect `chart/catalog/baseline-lbac.yaml` to confirm captured rules.
3. Commit and push. Pre-existing teams are now safely preserved and will merge with any new teams defined in `chart/teams/*.yaml`.

---

## 5. Troubleshooting & Diagnostics

### Issue 1: Argo CD App is OutOfSync on FolderPermissions, RoleAssignments, or DataSourcePermissionItems
- **Cause**: Crossplane reference resolution dynamically injects resolved numeric IDs (e.g. `teamId: 1:3096`) into `spec.forProvider`.
- **Fix**: Verify that `deploy/argocd/application.yaml` contains the `ignoreDifferences` configuration:
  ```yaml
  ignoreDifferences:
  - group: oss.grafana.m.crossplane.io
    kind: FolderPermission
    jqPathExpressions:
    - .spec.forProvider.permissions[].teamId
    - .spec.forProvider.permissions[].userId
  - group: enterprise.grafana.m.crossplane.io
    kind: RoleAssignment
    jsonPointers:
    - /spec/forProvider/teams
    - /spec/forProvider/serviceAccounts
  - group: enterprise.grafana.m.crossplane.io
    kind: DataSourcePermissionItem
    jsonPointers:
    - /spec/forProvider/team
  ```

### Issue 2: HTTP 429 Too Many Requests (Rate Limiting)
- **Cause**: Crossplane reconciling too many resources concurrently against Grafana Cloud.
- **Fix**: Ensure `deploy/crossplane/runtime-config.yaml` is applied with:
  ```yaml
  spec:
    deploymentTemplate:
      spec:
        template:
          spec:
            containers:
            - name: package-runtime
              args:
              - --max-reconcile-rate=10
              - --poll=10m
  ```

### Issue 3: Dashboards Stuck in Wave 2 (Not Syncing)
- **Cause**: A Wave 0 (Folder) or Wave 1 (Permission) dependency failed to reach `Ready=True`.
- **Diagnostic**:
  ```bash
  # Check which resources are not Healthy or Synced
  kubectl get gfolders,gfp -n crossplane-system -o jsonpath='{range .items[?(@.status.conditions[0].status!="True")]}{.kind}{"/"}{.metadata.name}{": "}{.status.conditions[0].message}{"\n"}{end}'
  ```
- **Fix**: Inspect the referenced folder UID in the dashboard JSON. Ensure the folder exists in `chart/folders/folders.yaml` or under `chart/dashboards/<FolderName>/`.
