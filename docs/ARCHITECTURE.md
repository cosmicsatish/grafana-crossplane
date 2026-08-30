# Architecture

The control plane has one reconciliation chain:

```text
Git
  |
  v
Argo CD
  |
  v
Helm chart
  |
  v
Crossplane managed resources
  |
  v
provider-grafana
  |
  v
Grafana Cloud
```

## Design principles

- No custom controllers.
- No custom runtime scripts.
- No Terraform.
- Keep resource definitions declarative and close to the Crossplane provider schema.
- Keep Grafana Cloud credentials outside Git.
- Keep stack-specific connection details in ProviderConfig/secret management and Helm values overlays.
- Use raw Crossplane resources for provider capabilities that do not yet have a convenience template.

## Native export transformation

Grafana exports resource-oriented JSON/YAML rather than Crossplane CR manifests. The repository therefore uses **Helm templates as the transformation layer**. Native Grafana exports are accepted directly for the supported resource families and are mapped at render time into Crossplane managed resources. This keeps the GitOps control plane declarative without introducing Python, shell synchronization logic, Terraform, or a custom controller.

When a Grafana export cannot carry enough information to build a stable Crossplane object, the supported fallback is the raw Crossplane manifest path under `chart/resources/`.
