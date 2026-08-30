#!/usr/bin/env bash
# Cleanup script - removes all provisioned resources from Grafana Cloud
# Preserves: extsvc-* service accounts, grafana-mcp (id 585), GrafanaCloud folder, Grafana Synthetic Monitoring folder
set -e

GRAFANA_URL="https://cosmicsatish.grafana.net"
# Use MCP token (admin)
TOKEN="${GRAFANA_TOKEN}"

if [ -z "$TOKEN" ]; then
  echo "ERROR: Set GRAFANA_TOKEN env var first"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer ${TOKEN}"

echo "============================================"
echo " Grafana Cloud Resource Cleanup"
echo "============================================"

# ── Service Accounts to delete (IDs created by provisioning, NOT extsvc-* or grafana-mcp id=585)
# From the search results, these are the provisioned ones (non-extsvc, not grafana-mcp):
# id 610: grafana-resource-provisioner
# id 611: markitserv-datasource-viewer-app
# id 612: config-reconciler
# id 613: toc-tools
# id 614: svc-call-grafana-api-toc
# id 615: grafana-operator
# id 616: config-reconciler-readonly-for-testing
# id 617: alert-provisioning-writer
# id 618: Satish-Personal-Token  (keep - personal)
# id 619: svc-api-gw
# id 620: MCP Grafana
# id 621: log-downloader
# id 622: log-downloader (duplicate?)
# id 623: Rama_personal_account (keep - personal)
# id 624: winops-automation
# id 625: screenly-test-app
# id 626: grafana-mcp-server
# id 627: API
# id 628: alerts-reader-ITS-30152

# Provisioned SA IDs to delete (NOT personal tokens, NOT extsvc-*, NOT grafana-mcp 585)
SA_IDS_TO_DELETE="610 611 612 613 614 615 616 617 619 620 621 622 624 625 626 627 628"

echo ""
echo "=> Deleting provisioned Service Accounts..."
for sa_id in $SA_IDS_TO_DELETE; do
  echo -n "   Deleting SA id=${sa_id}... "
  resp=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
    "${GRAFANA_URL}/api/serviceaccounts/${sa_id}" \
    -H "${AUTH_HEADER}")
  if [ "$resp" = "200" ] || [ "$resp" = "204" ]; then
    echo "OK (${resp})"
  else
    echo "SKIP/ERROR (${resp})"
  fi
  sleep 0.3
done

echo ""
echo "=> Deleting provisioned Teams..."
# All teams from IDs 3012-3050 were provisioned by us
for team_id in $(seq 3012 3050); do
  echo -n "   Deleting team id=${team_id}... "
  resp=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
    "${GRAFANA_URL}/api/teams/${team_id}" \
    -H "${AUTH_HEADER}")
  if [ "$resp" = "200" ] || [ "$resp" = "204" ]; then
    echo "OK (${resp})"
  elif [ "$resp" = "404" ]; then
    echo "Not found, skip"
  else
    echo "ERROR (${resp})"
  fi
  sleep 0.3
done

echo ""
echo "=> Deleting provisioned Folders..."
# All folders except: cfwolsg1l2uioc (GrafanaCloud), grafana-synthetic-monitoring-app (Grafana Synthetic Monitoring)
FOLDERS_TO_KEEP="cfwolsg1l2uioc grafana-synthetic-monitoring-app"

# Get all folder UIDs
FOLDER_UIDS=$(curl -s "${GRAFANA_URL}/api/folders?limit=200" -H "${AUTH_HEADER}" | \
  python3 -c "import sys,json; folders=json.load(sys.stdin); [print(f['uid']) for f in folders]" 2>/dev/null || \
  curl -s "${GRAFANA_URL}/api/folders?limit=200" -H "${AUTH_HEADER}" | \
  grep -o '"uid":"[^"]*"' | sed 's/"uid":"//;s/"//')

for uid in $FOLDER_UIDS; do
  # Skip preexisting
  if echo "$FOLDERS_TO_KEEP" | grep -qw "$uid"; then
    echo "   Keeping folder uid=${uid} (preexisting)"
    continue
  fi
  echo -n "   Deleting folder uid=${uid}... "
  resp=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
    "${GRAFANA_URL}/api/folders/${uid}" \
    -H "${AUTH_HEADER}")
  if [ "$resp" = "200" ] || [ "$resp" = "204" ]; then
    echo "OK (${resp})"
  elif [ "$resp" = "404" ]; then
    echo "Not found, skip"
  else
    echo "ERROR (${resp})"
  fi
  sleep 0.3
done

echo ""
echo "=> Cleanup complete!"
echo "   Remaining: extsvc-* SAs, grafana-mcp (id=585), GrafanaCloud folder, Grafana Synthetic Monitoring folder"
