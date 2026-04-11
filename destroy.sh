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

echo "NOTE: Destroying functions, Cosmos DB, web storage, and B2C app registration..."

export TF_VAR_b2c_tenant_id="$B2C_TENANT_ID"
export TF_VAR_b2c_tenant_name="$B2C_TENANT_NAME"
export TF_VAR_b2c_policy_name="$B2C_POLICY_NAME"
export TF_VAR_b2c_sp_client_id="$B2C_SP_CLIENT_ID"
export TF_VAR_b2c_sp_client_secret="$B2C_SP_CLIENT_SECRET"

cd 01-functions
terraform init -upgrade
terraform destroy -auto-approve
cd ..

echo "NOTE: Teardown complete."
