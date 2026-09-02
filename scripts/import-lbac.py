#!/usr/bin/env python3
"""
Import existing Label-Based Access Control (LBAC) rules from live Grafana data sources
and write them to chart/catalog/baseline-lbac.yaml to seed the GitOps baseline.
"""

import os
import sys
import json
import ssl
import urllib.request
import re

try:
    import yaml
except ImportError:
    print("ERROR: 'pyyaml' is required. Install it using: pip install pyyaml", file=sys.stderr)
    sys.exit(1)


def slugify(text: str) -> str:
    s = str(text).strip().lower()
    s = re.sub(r'[\s_]+', '-', s)
    s = re.sub(r'[^a-z0-9-]', '', s)
    s = re.sub(r'-+', '-', s).strip('-')
    return s or "team"


def main():
    url = os.environ.get("GRAFANA_URL", "").strip().rstrip("/")
    if not url:
        if sys.stdin.isatty():
            try:
                url = input("Enter your Grafana URL (e.g. https://<your-org>.grafana.net): ").strip().rstrip("/")
            except (EOFError, KeyboardInterrupt):
                sys.exit(1)
        if not url:
            print("ERROR: GRAFANA_URL environment variable is required.", file=sys.stderr)
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

    print(f"=> Fetching team registry from {url}...")
    team_uid_to_slug = {}
    try:
        req_teams = urllib.request.Request(f"{url}/api/teams/search?perpage=500", headers=headers)
        teams_data = json.loads(urllib.request.urlopen(req_teams, context=ctx).read().decode("utf-8"))
        for t in teams_data.get("teams", []):
            if t.get("uid"):
                team_uid_to_slug[t["uid"]] = slugify(t.get("name", t["uid"]))
        print(f"   Discovered {len(team_uid_to_slug)} teams.")
    except Exception as e:
        print(f"WARNING: Could not fetch teams registry: {e}. Will use UIDs as team keys.", file=sys.stderr)

    print(f"=> Scanning data sources for LBAC rules...")
    try:
        req_ds = urllib.request.Request(f"{url}/api/datasources", headers=headers)
        datasources = json.loads(urllib.request.urlopen(req_ds, context=ctx).read().decode("utf-8"))
    except Exception as e:
        print(f"ERROR: Failed to fetch datasources: {e}", file=sys.stderr)
        sys.exit(1)

    baseline_data = {}
    total_rules_found = 0

    for ds in datasources:
        ds_uid = ds.get("uid")
        ds_name = ds.get("name", ds_uid)
        if not ds_uid:
            continue

        try:
            req_lbac = urllib.request.Request(f"{url}/api/datasources/uid/{ds_uid}/lbac/teams", headers=headers)
            lbac_resp = json.loads(urllib.request.urlopen(req_lbac, context=ctx).read().decode("utf-8"))
            rules_list = lbac_resp.get("rules", [])
            if rules_list:
                print(f"   Found {len(rules_list)} LBAC rule(s) on datasource: {ds_name} ({ds_uid})")
                ds_entry = {
                    "datasourceName": ds_name,
                    "teams": {}
                }
                for r in rules_list:
                    t_uid = r.get("teamUid", "")
                    t_slug = team_uid_to_slug.get(t_uid, t_uid)
                    rule_strings = r.get("rules", [])
                    ds_entry["teams"][t_slug] = {
                        "teamUid": t_uid,
                        "rules": rule_strings
                    }
                    total_rules_found += len(rule_strings)
                baseline_data[ds_uid] = ds_entry
        except urllib.error.HTTPError:
            # Data source does not support LBAC (400, 404)
            pass
        except Exception as e:
            print(f"WARNING: Error checking LBAC for {ds_name}: {e}", file=sys.stderr)

    target_path = os.path.join("chart", "catalog", "baseline-lbac.yaml")
    os.makedirs(os.path.dirname(target_path), exist_ok=True)

    header_comment = (
        "# ==============================================================================\n"
        "# Baseline LBAC Rules Catalog\n"
        "# ==============================================================================\n"
        "# Holds pre-existing Label-Based Access Control (LBAC) rules on data sources.\n"
        "# Rules defined in chart/teams/*.yaml will automatically merge with and override\n"
        "# entries defined here for the same team.\n"
        "#\n"
        "# To re-import live existing rules from Grafana on Day 0:\n"
        "#   make import-lbac\n"
        "# ==============================================================================\n\n"
    )

    with open(target_path, "w", encoding="utf-8") as f:
        f.write(header_comment)
        yaml.dump(baseline_data, f, sort_keys=False, default_flow_style=False, allow_unicode=True, indent=2)

    print(f"\n=> Successfully written {total_rules_found} rules across {len(baseline_data)} data source(s) to {target_path}.")


if __name__ == "__main__":
    main()
