# Osttra Reference Stack Example

This directory contains the complete reference resources for the Osttra production stack:

- **Folders (`folders/folders.yaml`)**: 42 production folders with hierarchical UIDs, parent links, and permission policies.
- **Teams (`teams/*.yaml`)**: 39 production teams with SAML/OAuth sync group mappings, role presets, and folder permission grants.
- **Service Accounts (`serviceaccounts/serviceaccounts.yaml`)**: 19 service accounts with token definitions, TTLs, and RBAC roles.
- **Dashboards (`dashboards/Satish/`)**: Production Cost Attribution dashboard.

### How to use this stack or deploy it:
To deploy this stack instead of the starter resources, copy the contents of these directories into `chart/`:
```bash
cp examples/stacks/osttra/folders/folders.yaml chart/folders/
cp examples/stacks/osttra/teams/*.yaml chart/teams/
cp examples/stacks/osttra/serviceaccounts/serviceaccounts.yaml chart/serviceaccounts/
cp -r examples/stacks/osttra/dashboards/* chart/dashboards/
```
