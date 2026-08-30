# Operations Runbook

## Automated Bootstrap
 
To stand up or initialize the complete stack from scratch:
 
```bash
make bootstrap
```
 
The bootstrap script automatically provisions the cluster, sets up Argo CD with health checks, installs Crossplane with rate-limit runtime configs, creates credentials, and deploys the GitOps sync loop.
 
## Manual Deployment Path

Apply the Argo CD project and application:

```bash
kubectl apply -f deploy/argocd/project.yaml
kubectl apply -f deploy/argocd/application.yaml
```

## GitOps ownership

Git owns desired state. Argo CD owns applying the Helm chart. Crossplane owns reconciliation against Grafana. Avoid manual Grafana changes unless the resulting state is intentionally brought back into Git.

## Export/import

Use Grafana's native export functionality. See `docs/EXPORT-IMPORT.md`. The repository intentionally contains no custom conversion script.

## Validation

Run:

```bash
make validate
```

This performs Helm linting and rendering for the default and example stack overlays. Helm's chart schema validation covers `values.schema.json` during lint/render.

## Upgrades

Upgrade `provider-grafana` in a branch, run `make validate`, and test against a non-production stack first. Treat provider API-group or schema changes as compatibility events.

## Backout

Revert the Git commit. Argo CD restores the previous manifests and Crossplane reconciles the target state.
