# Operations Runbook

## Prerequisites

Crossplane and Argo CD are platform prerequisites. Install them using the platform's standard package-management process. This repository does not contain a custom bootstrap script.

After Crossplane is installed:

```bash
kubectl apply -f deploy/crossplane/provider.yaml
kubectl wait --for=condition=healthy provider.pkg.crossplane.io/provider-grafana --timeout=10m
```

Create the Grafana credentials Secret using your secret-management process, then apply the example ProviderConfig after reviewing the Secret reference.

## Deploy

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
