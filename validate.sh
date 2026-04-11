#!/bin/bash
set -euo pipefail

echo "NOTE: Running validation..."

cd 02-webapp
WEBSITE_URL=$(terraform output -raw website_url 2>/dev/null || true)
cd ..

echo ""
[ -n "${WEBSITE_URL:-}" ] && echo "NOTE: Web app: ${WEBSITE_URL}index.html"
echo "NOTE: All API endpoints require a valid B2C JWT — automated curl tests are skipped."
echo "NOTE: Sign in via the web app to exercise the full CRUD flow."
echo ""
