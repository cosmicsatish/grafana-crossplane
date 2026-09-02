#!/usr/bin/env bash
#!/usr/bin/env python3
"""
Sync fixed and plugin RBAC roles from Grafana Cloud/Enterprise to local YAML catalogs.
"""

import os
import sys
import json
import ssl
import urllib.request

try:
    import yaml
except ImportError:
    print("ERROR: 'pyyaml' is required. Install it using: pip install pyyaml", file=sys.stderr)
    sys.exit(1)


def main():
    url = os.environ.get("GRAFANA_URL", "").strip().rstrip("/")
    if not url:
        if sys.stdin.isatty():
            try:
                url = input("Enter your Grafana URL (e.g. https://<your-org>.grafana.net): ").strip().rstrip("/")
            except (EOFError, KeyboardInterrupt):
                sys.exit(1)
        if not url:
            print("ERROR: GRAFANA_URL environment variable is required (e.g. export GRAFANA_URL=https://<your-org>.grafana.net).", file=sys.stderr)
            sys.exit(1)

    token = os.environ.get("GRAFANA_TOKEN") or os.environ.get("GRAFANA_SERVICE_ACCOUNT_TOKEN", "").strip()
    if not token:
        if sys.stdin.isatty():
            import getpass
            try:
                token = getpass.getpass("Enter your Grafana Admin Service Account Token: ").strip()
            except (EOFError, KeyboardInterrupt):
                sys.exit(1)
        if not token:
            print("ERROR: GRAFANA_TOKEN environment variable is required.", file=sys.stderr)
            sys.exit(1)

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "User-Agent": "grafana-crossplane-sync/1.0"
    }
    ctx = ssl._create_unverified_context()

    req = urllib.request.Request(f"{url}/api/access-control/roles", headers=headers)
    try:
        with urllib.request.urlopen(req, context=ctx) as resp:
            if resp.status != 200:
                print(f"ERROR: HTTP {resp.status} fetching roles from {url}", file=sys.stderr)
                sys.exit(1)
            roles = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print(f"ERROR: Failed to fetch roles from {url}: HTTP {e.code} - {e.reason}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: Failed to connect to {url}: {e}", file=sys.stderr)
        sys.exit(1)

    if not isinstance(roles, list):
        print(f"ERROR: Unexpected response format, expected list of roles, got {type(roles)}", file=sys.stderr)
        sys.exit(1)

    fixed_roles = sorted([
        {"name": r["name"], "uid": r["uid"]}
        for r in roles
        if r.get("name", "").startswith("fixed:") and r.get("uid")
    ], key=lambda r: r["name"])

    plugin_roles = sorted([
        {"name": r["name"], "uid": r["uid"]}
        for r in roles
        if r.get("name", "").startswith("plugins:") and r.get("uid")
    ], key=lambda r: r["name"])

    fixed_path = os.path.join("chart", "catalog", "fixed-roles.yaml")
    plugin_path = os.path.join("chart", "catalog", "stacks", "default", "plugin-roles.yaml")

    os.makedirs(os.path.dirname(fixed_path), exist_ok=True)
    os.makedirs(os.path.dirname(plugin_path), exist_ok=True)

    with open(fixed_path, "w", encoding="utf-8") as f:
        yaml.dump(fixed_roles, f, sort_keys=False, default_flow_style=False, allow_unicode=True, indent=2)

    with open(plugin_path, "w", encoding="utf-8") as f:
        yaml.dump(plugin_roles, f, sort_keys=False, default_flow_style=False, allow_unicode=True, indent=2)

    print(f"Successfully synced {len(fixed_roles)} fixed roles and {len(plugin_roles)} plugin roles from {url}.")


if __name__ == "__main__":
    main()
