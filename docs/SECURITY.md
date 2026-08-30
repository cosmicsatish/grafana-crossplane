# Security model

- Credentials are created in Kubernetes secrets and referenced by Crossplane ProviderConfig.
- Export normalization redacts exact secret-bearing fields by default.
- Service account tokens are written to connection secrets by Crossplane rather than committed to Git.
- Avoid global Admin/Editor service account roles; prefer least-privilege fixed roles.
- LBAC selectors and datasource permissions are configuration, not credentials.
