#!/bin/bash
set -euo pipefail

./check_env.sh

echo "NOTE: Destroying web app..."
cd 02-webapp
terraform init -upgrade
terraform destroy -auto-approve
cd ..

echo "NOTE: Destroying functions and Cosmos DB..."
cd 01-functions
terraform init -upgrade
terraform destroy -auto-approve
cd ..

echo "NOTE: Teardown complete."
