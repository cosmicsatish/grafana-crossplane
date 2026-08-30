SHELL := /bin/bash
CHART := chart
RELEASE := grafana-admin

.PHONY: lint render validate

lint:
	command -v helm >/dev/null || (echo "helm is required" >&2; exit 1)
	helm lint $(CHART)
	helm lint $(CHART) -f $(CHART)/values-osttra.yaml

render:
	command -v helm >/dev/null || (echo "helm is required" >&2; exit 1)
	helm template $(RELEASE) $(CHART)
	helm template $(RELEASE) $(CHART) -f $(CHART)/values-osttra.yaml

validate: lint render
