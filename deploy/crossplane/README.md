# Crossplane provider bootstrap
 
Run the automated bootstrap command:
 
```bash
make bootstrap
```
 
Or follow the declarative step-by-step process below.
 
## 1. Install Crossplane

Install the upstream Crossplane Helm chart using your platform's normal package-management process. Pin the Crossplane version according to your platform compatibility policy.

## 2. Create the provider credentials Secret

Create `crossplane-system/grafana-provider-credentials` using your secret-management process. The `credentials` key must contain:

```json
{"url":"https://<stack>.grafana.net","auth":"<service-account-token>"}
```

Do not commit the token or this populated Secret to Git.

## 3. Install provider-grafana

```bash
kubectl apply -f deploy/crossplane/provider.yaml
kubectl wait --for=condition=healthy provider.pkg.crossplane.io/provider-grafana --timeout=10m
```

## 4. Install ProviderConfig

Copy `providerconfig.yaml.example` to a local, untracked file, verify the Secret name/namespace, and apply it:

```bash
kubectl apply -f deploy/crossplane/providerconfig.yaml.example
```

## 5. Deploy the Grafana GitOps application

Install Argo CD using your platform standard, then apply:

```bash
kubectl apply -f deploy/argocd/project.yaml
kubectl apply -f deploy/argocd/application.yaml
```

The repository's application is the only object that needs to change per environment; target-stack values belong in the selected Helm values overlay.
