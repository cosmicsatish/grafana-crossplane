# Grafana GitOps Control Plane

A declarative Grafana Cloud GitOps repository built with **Helm + Crossplane provider-grafana + Argo CD**.

```text
Git → Argo CD → Helm → Crossplane → provider-grafana → Grafana Cloud
```

The repository intentionally contains **no custom runtime scripts, no custom controllers, and no Terraform**.

## What is managed

Convenience templates cover teams, folders, service accounts/tokens, dashboards, datasources, datasource permissions/LBAC, role assignments, alerting resources, SLOs and Synthetic Monitoring. `chart/resources/` is the escape hatch for any provider-grafana resource that does not need a dedicated convenience template.

See `docs/RESOURCE-COVERAGE.md`.

## Repository layout

```text
chart/
  dashboards/<folder>/
  alert-rules/<folder>/
  contact-points/<folder>/
  notification-policies/<folder>/
  mute-timings/<folder>/
  message-templates/<folder>/
  datasources/
  folders/
  serviceaccounts/
  teams/
  slos/
  synthetic-monitoring/
  resources/                 # raw Crossplane resources
  catalog/                   # optional stack-derived catalogs
  templates/                 # thin Helm translations

deploy/
  argocd/                    # Argo CD application/project
  crossplane/                # provider + ProviderConfig example

docs/
examples/
policy/
```

## Daily usage

Put desired state in the matching `chart/` directory, then:

```bash
make validate
```

Review the Git diff and merge. Argo CD applies the chart and Crossplane reconciles Grafana Cloud.

## Existing Grafana resources

Use Grafana Cloud's native export functionality and place the exported file directly under the matching `chart/` directory. The Helm chart is the transformation layer: it recognizes the native Grafana export shapes and renders the corresponding Crossplane resources. No exporter, normalizer, Python utility, shell script, Terraform module, or custom controller is required.

For resources whose Grafana export does not contain enough information to reconstruct a Crossplane object (for example some Cloud control-plane and provider-specific resources), commit the complete Crossplane manifest under `chart/resources/`. See `docs/EXPORT-IMPORT.md` for the exact mappings.

## Multi-stack

Resource definitions are stack-neutral. The target stack is selected through the Crossplane `ProviderConfig` and a values overlay. Do not put Grafana credentials in resource files.

For logical datasource references:

```yaml
datasourceAliases:
  logs:
    uid: <stack-local-datasource-uid>
```

LBAC remains opt-in and is configured against the target stack's datasource UID.

## Bootstrap

There is no repository bootstrap script by design.

Install Crossplane and Argo CD using your platform's standard package-management process. Then apply the declarative provider resources under `deploy/crossplane/` and the Argo CD objects under `deploy/argocd/`.

See `deploy/crossplane/README.md` and `OPERATIONS.md`.

## Security

Do not commit Grafana tokens, integration keys, datasource passwords, or populated ProviderConfig credentials. Keep provider credentials in Kubernetes Secret management outside Git.

See `docs/SECURITY.md`.

## Provider compatibility

The repository pins `xpkg.upbound.io/grafana/provider-grafana:v2.14.0` in the declarative provider package manifest. Review provider release notes before upgrading and run the validation suite in a branch before deployment.

## Validation

The repository validation path is deliberately simple:

```bash
make validate
```

It uses Helm only. No Python runtime is required.
