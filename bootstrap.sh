#!/usr/bin/env bash
set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

CLUSTER_NAME="grafana-admin-gitops"
KIND_BIN=$(which kind || echo "/usr/local/bin/kind")
KUBECTL_BIN=$(which kubectl || echo "/usr/local/bin/kubectl")
HELM_BIN=$(which helm || echo "/opt/homebrew/bin/helm")

echo "=========================================="
echo " Starting Bootstrap Process"
echo "=========================================="

# 1. Create Cluster
if ! $KIND_BIN get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "=> Creating Kind cluster: ${CLUSTER_NAME}"
  $KIND_BIN create cluster --name "${CLUSTER_NAME}"
else
  echo "=> Kind cluster ${CLUSTER_NAME} already exists."
fi

# Ensure we are using the correct context
$KUBECTL_BIN config use-context kind-${CLUSTER_NAME}

# 2. Install ArgoCD
echo "=> Installing ArgoCD..."
$KUBECTL_BIN create namespace argocd --dry-run=client -o yaml | $KUBECTL_BIN apply -f -
$KUBECTL_BIN apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side=true --force-conflicts

echo "=> Waiting for ArgoCD to be ready..."
$KUBECTL_BIN wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s
$KUBECTL_BIN wait --for=condition=Available deployment/argocd-repo-server -n argocd --timeout=300s
$KUBECTL_BIN rollout status statefulset/argocd-application-controller -n argocd --timeout=300s

if [ -f deploy/argocd/argocd-cm.yaml ]; then
    echo "=> Applying ArgoCD custom resource health checks..."
    $KUBECTL_BIN apply -f deploy/argocd/argocd-cm.yaml
    echo "=> Reloading ArgoCD application-controller..."
    $KUBECTL_BIN rollout restart statefulset/argocd-application-controller -n argocd
    $KUBECTL_BIN rollout status statefulset/argocd-application-controller -n argocd --timeout=120s
fi
echo "=> ArgoCD installed and ready!"

# 3. Install Crossplane
echo "=> Installing Crossplane..."
if ! $HELM_BIN repo list 2>/dev/null | grep -q "crossplane-stable"; then
    $HELM_BIN repo add crossplane-stable https://charts.crossplane.io/stable
fi
$HELM_BIN repo update
$HELM_BIN upgrade --install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system \
  --create-namespace \
  --wait

echo "=> Crossplane installed and ready!"

# 4. Configure Grafana Credentials
echo "=> Checking for Grafana Provider Credentials..."
if ! $KUBECTL_BIN get secret grafana-provider-creds -n crossplane-system > /dev/null 2>&1; then
    echo "Secret grafana-provider-creds not found."
    GRAFANA_URL="${GRAFANA_URL:-https://cosmicsatish.grafana.net}"

    if [ -z "${GRAFANA_TOKEN}" ]; then
        read -rsp "Enter your Grafana Cloud Admin Service Account Token: " GRAFANA_TOKEN
        echo "" # newline after prompt
    else
        echo "=> Using GRAFANA_TOKEN from environment."
    fi

    echo "=> Creating secret grafana-provider-creds in crossplane-system namespace..."
    $KUBECTL_BIN create secret generic grafana-provider-creds \
        -n crossplane-system \
        --from-literal=credentials="{\"url\":\"${GRAFANA_URL}\",\"auth\":\"${GRAFANA_TOKEN}\"}"
else
    echo "=> Secret grafana-provider-creds already exists."
fi

# 5. Apply Crossplane Provider Configurations
echo "=> Applying Crossplane Provider configurations..."
if [ -f deploy/crossplane/runtime-config.yaml ]; then
    echo "=> Applying DeploymentRuntimeConfig for provider rate limits..."
    $KUBECTL_BIN apply -f deploy/crossplane/runtime-config.yaml
fi

$KUBECTL_BIN apply -f deploy/crossplane/provider.yaml

echo "=> Waiting for Grafana provider to be installed and healthy..."
sleep 5 # wait a moment for the provider to be created
$KUBECTL_BIN wait --for=condition=Installed provider/provider-grafana --timeout=300s
$KUBECTL_BIN wait --for=condition=Healthy provider/provider-grafana --timeout=300s

# Apply providerconfig (create from example if missing)
if [ ! -f deploy/crossplane/providerconfig.yaml ] && [ -f deploy/crossplane/providerconfig.yaml.example ]; then
    echo "=> Copying providerconfig.yaml.example to providerconfig.yaml..."
    cp deploy/crossplane/providerconfig.yaml.example deploy/crossplane/providerconfig.yaml
fi
if [ -f deploy/crossplane/providerconfig.yaml ]; then
    $KUBECTL_BIN apply -f deploy/crossplane/providerconfig.yaml
elif [ -f deploy/crossplane/providerconfig.yaml.example ]; then
    $KUBECTL_BIN apply -f deploy/crossplane/providerconfig.yaml.example
fi

# 6. Configure ArgoCD Repository Access
echo "=> Configuring ArgoCD repository credentials..."
if ! $KUBECTL_BIN get secret argocd-repo-github -n argocd > /dev/null 2>&1; then
    _GH_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN:-${GITHUB_TOKEN}}"
    if [ -n "${_GH_TOKEN}" ]; then
        echo "=> Using GitHub token for repository authentication."
        $KUBECTL_BIN create secret generic argocd-repo-github \
            -n argocd \
            --from-literal=type=git \
            --from-literal=url=https://github.com/cosmicsatish/grafana-crossplane.git \
            --from-literal=username=cosmicsatish \
            --from-literal=password="${_GH_TOKEN}"
        $KUBECTL_BIN label secret argocd-repo-github -n argocd \
            argocd.argoproj.io/secret-type=repository
        echo "=> ArgoCD repository secret created."
    else
        echo "=> Public repository: proceeding with unauthenticated repository access."
    fi
else
    echo "=> ArgoCD repository secret already exists."
fi

# 7. Deploy ArgoCD Application
echo "=> Deploying ArgoCD Application to continuously sync resources..."
$KUBECTL_BIN apply -f deploy/argocd/project.yaml
$KUBECTL_BIN apply -f deploy/argocd/application.yaml

echo "=========================================="
echo " Bootstrap Process Completed Successfully!"
echo "=========================================="
echo ""
echo "To access ArgoCD UI locally, you can port-forward:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  (Username: admin, Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d)"
echo ""
