PATH := /opt/homebrew/bin:/usr/local/bin:$(PATH)
SHELL := /bin/bash
CHART := chart
RELEASE := grafana-crossplane
HELM ?= $(shell command -v helm 2>/dev/null || which /opt/homebrew/bin/helm /usr/local/bin/helm 2>/dev/null | head -n 1 || echo helm)

.PHONY: lint render validate bootstrap sync-roles

bootstrap:
	./bootstrap.sh

lint:
	command -v $(HELM) >/dev/null || (echo "helm is required" >&2; exit 1)
	$(HELM) lint $(CHART)

render:
	command -v $(HELM) >/dev/null || (echo "helm is required" >&2; exit 1)
	$(HELM) template $(RELEASE) $(CHART)

validate: lint render

sync-roles:

	@python3 - << 'EOF'
	import urllib.request, json, ssl, yaml, os, sys
	url = os.environ.get("GRAFANA_URL")
	if not url:
	    print("ERROR: GRAFANA_URL environment variable is required (e.g. export GRAFANA_URL=https://<your-org>.grafana.net).", file=sys.stderr)
	    sys.exit(1)
	url = url.rstrip("/")
	token = os.environ.get("GRAFANA_TOKEN")
	if not token:
	    print("ERROR: GRAFANA_TOKEN environment variable is required to sync roles.", file=sys.stderr)
	    sys.exit(1)
	headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json", "User-Agent": "grafana-crossplane-sync/1.0"}
	ctx = ssl._create_unverified_context()
	req = urllib.request.Request(f"{url}/api/access-control/roles", headers=headers)
	roles = json.loads(urllib.request.urlopen(req, context=ctx).read().decode("utf-8"))
	fixed = sorted([{"name": r["name"], "uid": r["uid"]} for r in roles if r.get("name", "").startswith("fixed:") and r.get("uid")], key=lambda r: r["name"])
	plugins = sorted([{"name": r["name"], "uid": r["uid"]} for r in roles if r.get("name", "").startswith("plugins:") and r.get("uid")], key=lambda r: r["name"])
	yaml.dump(fixed, open("chart/catalog/fixed-roles.yaml", "w"), sort_keys=False, default_flow_style=False, allow_unicode=True, indent=2)
	yaml.dump(plugins, open("chart/catalog/stacks/default/plugin-roles.yaml", "w"), sort_keys=False, default_flow_style=False, allow_unicode=True, indent=2)
	print(f"Successfully synced {len(fixed)} fixed roles and {len(plugins)} plugin roles from {url}.")
	EOF

