PATH := /opt/homebrew/bin:/usr/local/bin:$(PATH)
SHELL := /bin/bash
CHART := chart
RELEASE := grafana-admin
HELM ?= $(shell command -v helm 2>/dev/null || which /opt/homebrew/bin/helm /usr/local/bin/helm 2>/dev/null | head -n 1 || echo helm)

.PHONY: lint render validate

lint:
	command -v $(HELM) >/dev/null || (echo "helm is required" >&2; exit 1)
	$(HELM) lint $(CHART)
	$(HELM) lint $(CHART) -f $(CHART)/values-osttra.yaml

render:
	command -v $(HELM) >/dev/null || (echo "helm is required" >&2; exit 1)
	$(HELM) template $(RELEASE) $(CHART)
	$(HELM) template $(RELEASE) $(CHART) -f $(CHART)/values-osttra.yaml

validate: lint render
