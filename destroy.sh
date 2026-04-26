#!/bin/bash
set -euo pipefail

./check_env.sh

# Read outputs before state is destroyed.
cd 01-functions
WEB_STORAGE_NAME=$(terraform output -raw web_storage_name 2>/dev/null || true)
ENTRA_CLIENT_ID=$(terraform output -raw entra_client_id 2>/dev/null || true)
cd ..

echo "NOTE: Destroying web app..."
cd 02-webapp
terraform init -upgrade
terraform destroy -auto-approve -var="web_storage_name=${WEB_STORAGE_NAME:-placeholder}"
cd ..


# ── Phase 1.5 cleanup: remove app from Entra user flow ────────────────────────

echo "NOTE: Removing notes-entra-app from user flow '${ENTRA_USER_FLOW_NAME}'..."

# Retried up to 10 times — failures are non-fatal; destroy continues regardless.
_remove_app() {
  if [[ -z "$ENTRA_CLIENT_ID" ]]; then
    echo "NOTE: No Entra client ID in state. Skipping association cleanup."
    return 0
  fi

  GRAPH_TOKEN=$(curl -s -X POST \
    "https://login.microsoftonline.com/${ENTRA_TENANT_ID}/oauth2/v2.0/token" \
    --data-urlencode "grant_type=client_credentials" \
    --data-urlencode "client_id=${ENTRA_SP_CLIENT_ID}" \
    --data-urlencode "client_secret=${ENTRA_SP_CLIENT_SECRET}" \
    --data-urlencode "scope=https://graph.microsoft.com/.default" \
    | jq -r '.access_token')

  if [[ -z "$GRAPH_TOKEN" || "$GRAPH_TOKEN" == "null" ]]; then
    echo "WARNING: Could not acquire Graph token."
    return 1
  fi

  FLOW_ID=$(curl -s -G \
    --data-urlencode "\$filter=displayName eq '${ENTRA_USER_FLOW_NAME}'" \
    "https://graph.microsoft.com/v1.0/identity/authenticationEventsFlows" \
    -H "Authorization: Bearer ${GRAPH_TOKEN}" \
    | jq -r '.value[0].id')

  if [[ -z "$FLOW_ID" || "$FLOW_ID" == "null" ]]; then
    echo "NOTE: User flow '${ENTRA_USER_FLOW_NAME}' not found. Skipping."
    return 0
  fi

  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
    "https://graph.microsoft.com/v1.0/identity/authenticationEventsFlows/${FLOW_ID}/conditions/applications/includeApplications/${ENTRA_CLIENT_ID}" \
    -H "Authorization: Bearer ${GRAPH_TOKEN}")

  if [[ "$HTTP_STATUS" == "204" ]]; then
    echo "NOTE: App removed from user flow."
    return 0
  elif [[ "$HTTP_STATUS" == "404" ]]; then
    echo "NOTE: App was not associated with user flow (already clean)."
    return 0
  fi

  echo "WARNING: Unexpected status removing app from user flow (HTTP ${HTTP_STATUS})."
  return 1
}

_GRAPH_MAX=10
_GRAPH_DELAY=30
for _attempt in $(seq 1 $_GRAPH_MAX); do
  if _remove_app; then
    break
  fi
  if [[ $_attempt -lt $_GRAPH_MAX ]]; then
    echo "NOTE: Retrying in ${_GRAPH_DELAY}s (attempt ${_attempt}/${_GRAPH_MAX})..."
    sleep $_GRAPH_DELAY
  else
    echo "WARNING: Phase 1.5 cleanup failed after ${_GRAPH_MAX} attempts. Continuing with destroy..."
  fi
done


# ── Destroy infrastructure ─────────────────────────────────────────────────────

echo "NOTE: Destroying functions, Cosmos DB, web storage, and Entra app registration..."

export TF_VAR_entra_tenant_id="$ENTRA_TENANT_ID"
export TF_VAR_entra_tenant_name="$ENTRA_TENANT_NAME"
export TF_VAR_entra_sp_client_id="$ENTRA_SP_CLIENT_ID"
export TF_VAR_entra_sp_client_secret="$ENTRA_SP_CLIENT_SECRET"

cd 01-functions
terraform init -upgrade
terraform destroy -auto-approve
cd ..

echo "NOTE: Teardown complete."
