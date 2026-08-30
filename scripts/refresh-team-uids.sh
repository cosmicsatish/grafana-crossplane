#!/usr/bin/env bash
# Regenerates chart/catalog/team-uids.yaml from live cluster state
# Run AFTER wave 0 (Teams) are Ready in ArgoCD
set -e

KUBECTL_BIN=$(which kubectl || echo "/usr/local/bin/kubectl")
CATALOG_FILE="chart/catalog/team-uids.yaml"

echo "=> Waiting for all Teams to be Ready..."
# Wait up to 5 minutes for all teams to be ready
TIMEOUT=300
START=$(date +%s)
while true; do
  TOTAL=$($KUBECTL_BIN get teams.oss.grafana.m.crossplane.io -n crossplane-system --no-headers 2>/dev/null | wc -l | tr -d ' ')
  READY=$($KUBECTL_BIN get teams.oss.grafana.m.crossplane.io -n crossplane-system -o json 2>/dev/null | \
    python3 -c "
import sys,json
d=json.load(sys.stdin)
print(sum(1 for i in d['items'] for c in i.get('status',{}).get('conditions',[]) if c['type']=='Ready' and c['status']=='True'))
" 2>/dev/null || echo 0)
  echo "   Teams: ${READY}/${TOTAL} ready"
  if [ "$TOTAL" -gt 0 ] && [ "$READY" -eq "$TOTAL" ]; then
    break
  fi
  NOW=$(date +%s)
  if [ $((NOW - START)) -ge $TIMEOUT ]; then
    echo "Timeout waiting for teams. Generating with available UIDs."
    break
  fi
  sleep 10
done

echo "=> Generating ${CATALOG_FILE}..."
cat > "${CATALOG_FILE}" << 'HEADER'
# AUTO-GENERATED - maps team slug -> Grafana-assigned team UID
# Regenerate: bash scripts/refresh-team-uids.sh
#
HEADER

$KUBECTL_BIN get teams.oss.grafana.m.crossplane.io -n crossplane-system -o json | \
  python3 -c "
import sys, json
d = json.load(sys.stdin)
entries = []
for item in d['items']:
    slug = item['metadata']['name']
    uid = item.get('status', {}).get('atProvider', {}).get('uid', '') or \
          item.get('status', {}).get('atProvider', {}).get('teamUid', '')
    if uid:
        entries.append((slug, uid))
entries.sort()
for slug, uid in entries:
    print(f'{slug}: {uid}')
" >> "${CATALOG_FILE}"

COUNT=$(grep -c "^[a-z]" "${CATALOG_FILE}" || echo 0)
echo "=> Generated ${COUNT} team UID mappings in ${CATALOG_FILE}"
cat "${CATALOG_FILE}"
