# Grafana export/import workflow

This repository uses **Helm as the only transformation layer**. There are no custom Python utilities, shell export/normalization scripts, Terraform modules, or custom controllers. The intended path is:

```text
Grafana Cloud native export
        ↓
place file directly in the matching chart/ directory
        ↓
Helm template mapping
        ↓
Crossplane managed resource
        ↓
provider-grafana
        ↓
Grafana Cloud
```

Grafana's alerting export endpoints produce provisioning-file formats rather than Crossplane manifests. The chart therefore accepts the native provisioning shapes and maps them to the provider CRDs at render time. Grafana documents separate exports for alert rules, contact points, notification policies, and mute timings.

## Direct placement rules

Use the corresponding directory; subdirectories are retained as folder hints and can be nested:

```text
chart/dashboards/<folder>/<dashboard>.json
chart/alert-rules/<folder>/<rules>.yaml
chart/contact-points/<folder>/<contact-points>.yaml
chart/notification-policies/<folder>/<policy>.yaml
chart/mute-timings/<folder>/<mute-times>.yaml
chart/message-templates/<folder>/<templates>.yaml
chart/datasources/<datasource>.yaml
```

Do not convert the native Grafana export into a Crossplane YAML file first. The Helm templates recognize the native field names and emit the appropriate `oss.grafana.m.crossplane.io` or `alerting.grafana.m.crossplane.io` resources.

## Native alerting formats handled

### Alert rules

The chart accepts the Grafana provisioning export shape with:

```yaml
apiVersion: 1
groups:
  - orgId: 1
    name: Linux Alerts
    folder: Satish
    interval: 1m
    rules: [...]
```

It maps `groups[].rules[]` into `alerting.grafana.m.crossplane.io/v1alpha1` `RuleGroup` objects. `interval`, `data`, `relativeTimeRange`, `datasourceUid`, labels, annotations, no-data/error state, and notification settings are supported. Native `object_matchers` and nested route trees are also mapped.

### Contact points

The native `contactPoints[].receivers[]` shape is accepted. Common receiver types supported by the provider and chart include email, Slack, PagerDuty, webhook, Opsgenie, Microsoft Teams, Discord, Google Chat, Telegram, SNS, Jira, Alertmanager, OnCall, Webex and DingDing.

Sensitive values must remain outside Git. Where Grafana returns a secret reference/redacted value, keep the corresponding Crossplane `*SecretRef` field in the manifest. The chart does not intentionally copy known password/API-token fields from native receiver settings into Git-managed manifests.

### Notification policies

The Grafana native `policies` form is accepted, including `group_by`, `group_wait`, `group_interval`, `repeat_interval`, `mute_time_intervals`, `active_time_intervals`, nested `routes`, and `object_matchers`.

### Mute timings

The native `muteTimes[].intervals` form is accepted as well as the compact repository `muteTimings[].intervals` form.

### Notification message templates

The chart accepts `templates[]` and the repository `messageTemplates[]` shape. Grafana does not currently provide the same export endpoint for template groups as it does for other alerting resources, so template files normally come from the provisioning/API representation or are maintained directly.

## Dashboards

Dashboard JSON is accepted in two common forms:

1. Direct dashboard model JSON.
2. Grafana export JSON wrapped as `dashboard: {...}` with optional `meta`.

Dashboard v2 manifests using `apiVersion: dashboard.grafana.app/...` are mapped to `DashboardV2`. Other dashboard JSON is preserved as the dashboard `configJson`. Folder names inferred from the repository path are converted into deterministic folder UIDs.

## Folders

Folders can be declared explicitly under `chart/folders/`. For exported dashboards and alert groups, the chart can also create missing folders automatically from the directory path or native `folder` value. Explicit folder definitions win over an automatically discovered folder with the same UID. Nested paths use deterministic parent folder UIDs.

## Datasources

Datasource files may be a single datasource object, a list, `datasources: [...]`, or `dataSources: [...]`. Common Grafana export fields such as `access`, `basicAuth`, `basicAuthUser`, `jsonData`, `uid`, `type`, `url`, and `isDefault` are mapped to the Crossplane provider's `accessMode`, `basicAuthEnabled`, `basicAuthUsername`, `jsonDataEncoded`, and related fields. Sensitive datasource passwords should be supplied through provider-supported Secret references rather than committed values.

## Resources without a native Grafana export compatible with this chart

Some Grafana Cloud resources do not have a native export that contains enough information to reconstruct their Crossplane CR directly. This includes Cloud control-plane resources such as access policies/tokens and provider-specific resources such as SLO/Synthetic Monitoring objects. For these resources, place the **complete Crossplane manifest** under `chart/resources/` rather than pretending the Grafana API response is already a Crossplane resource.

This is still a no-script design: the GitOps controller consumes the Crossplane manifest directly.

## Multi-stack portability

Do not hard-code Grafana organization IDs or Kubernetes-generated metadata. Prefer stable Grafana UIDs, deterministic folder UIDs, provider references, and datasource aliases. The same resource files should be reusable across stacks with environment-specific provider configuration supplied separately.

## Validation

Use the normal repository validation command before merge:

```text
make validate
```

The repository's CI validates the chart templates and values schema. A live integration test against Grafana Cloud requires credentials and a target stack and is intentionally not embedded in the repository.

## Official Grafana export documentation

See Grafana's current alerting export documentation for the native provisioning formats and export endpoints:
https://grafana.com/docs/grafana/latest/alerting/set-up/provision-alerting-resources/export-alerting-resources/
