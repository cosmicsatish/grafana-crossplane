# Troubleshooting

### `no matches for kind ...`

Check that the installed provider version contains the API group and kind used by the manifest. Run:

```bash
kubectl api-resources | grep grafana
kubectl get crd | grep grafana
```

### A resource reconciles but points at the wrong stack

Check the `providerConfigRef` on the generated manifest and verify the referenced ProviderConfig secret contains the intended Grafana URL/token.

### Export causes endless Git diffs

Normalize the export before committing it. Remove status/server metadata and timestamps. Do not round-trip Kubernetes-generated metadata back into Git.

### Datasource permissions reference the wrong UID

Use the logical datasource alias or the actual UID in the datasource declaration. Do not hard-code a stack-specific UID in unrelated team manifests.

### Token duration looks wrong

`m` means months in this repository. Use `min`/`minute` for minutes.
