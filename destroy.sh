#!/bin/bash
set -euo pipefail

./check_env.sh

# Read the storage name before the backend state is destroyed.
cd 01-functions
WEB_STORAGE_NAME=$(terraform output -raw web_storage_name 2>/dev/null || true)
cd ..

echo "NOTE: Destroying web app..."
cd 02-webapp
terraform init -upgrade
terraform destroy -auto-approve -var="web_storage_name=${WEB_STORAGE_NAME:-placeholder}"
cd ..

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
