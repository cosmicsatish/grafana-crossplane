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
	python3 scripts/sync-roles.py


