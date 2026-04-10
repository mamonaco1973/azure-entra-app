#!/bin/bash
set -euo pipefail

./check_env.sh


# ── Phase 1: Functions + Cosmos DB ────────────────────────────────────────────

echo "NOTE: Deploying functions and Cosmos DB..."
cd 01-functions
terraform init -upgrade
terraform apply -auto-approve

RESOURCE_GROUP=$(terraform output -raw resource_group_name)
cd ..


# ── Phase 2: Deploy function code ─────────────────────────────────────────────

echo "NOTE: Packaging and deploying function code..."
cd 01-functions/code

rm -f app.zip
zip -r app.zip . \
  -x "*.git*" \
  -x "*__pycache__*" \
  -x "*.pytest_cache*" \
  -x "*.DS_Store"

FUNC_APP_NAME=$(az functionapp list \
  --resource-group "$RESOURCE_GROUP" \
  --query "[?starts_with(name, 'notes-func-')].name" \
  --output tsv)

az functionapp deployment source config-zip \
  --name "$FUNC_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --src app.zip \
  --build-remote true

cd ../..

API_BASE="https://$(az functionapp show \
  --name "$FUNC_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.defaultHostName" \
  -o tsv)/api"

export API_BASE
echo "NOTE: Function app: ${FUNC_APP_NAME}"
echo "NOTE: API base:     ${API_BASE}"


# ── Phase 3: Web app ──────────────────────────────────────────────────────────

echo "NOTE: Building web app..."
envsubst '${API_BASE}' < 02-webapp/index.html.tmpl > 02-webapp/index.html

cd 02-webapp
terraform init -upgrade
terraform apply -auto-approve

WEBSITE_URL=$(terraform output -raw website_url)
cd ..

echo ""
echo "NOTE: Deployment complete."
echo "NOTE: API:     ${API_BASE}"
echo "NOTE: Web app: ${WEBSITE_URL}index.html"
echo ""

./validate.sh
