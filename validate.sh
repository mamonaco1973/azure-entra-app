#!/bin/bash
set -euo pipefail

echo "NOTE: Running validation..."

cd 01-functions
API_BASE=$(terraform output -raw function_app_url)
cd ..

echo "NOTE: Testing API at: ${API_BASE}"

# ── Create ────────────────────────────────────────────────────────────────────

echo "NOTE: Creating 5 test notes..."
NOTE_IDS=()

for i in {1..5}; do
  PAYLOAD=$(jq -n --arg t "Test Note ${i}" --arg n "Content ${i}" '{title:$t,note:$n}')
  ID=$(curl -sf -X POST "${API_BASE}/notes" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}" | jq -r '.id // empty')

  if [[ -z "${ID}" ]]; then
    echo "ERROR: Failed to create note ${i}"
    exit 1
  fi

  NOTE_IDS+=("${ID}")
  echo "NOTE: Created note ${i} (id=${ID})"
done

# ── List ──────────────────────────────────────────────────────────────────────

echo "NOTE: Listing notes..."
COUNT=$(curl -sf "${API_BASE}/notes" | jq '.items | length')

if [[ "${COUNT}" -lt 5 ]]; then
  echo "ERROR: Expected at least 5 notes, got ${COUNT}"
  exit 1
fi
echo "NOTE: List returned ${COUNT} notes — OK"

# ── Get ───────────────────────────────────────────────────────────────────────

echo "NOTE: Fetching each note by ID..."
for ID in "${NOTE_IDS[@]}"; do
  TITLE=$(curl -sf "${API_BASE}/notes/${ID}" | jq -r '.title // empty')
  if [[ -z "${TITLE}" ]]; then
    echo "ERROR: Failed to fetch note ${ID}"
    exit 1
  fi
  echo "NOTE: Get ${ID} (${TITLE}) — OK"
done

# ── Update ────────────────────────────────────────────────────────────────────

echo "NOTE: Updating each note..."
for ID in "${NOTE_IDS[@]}"; do
  PAYLOAD=$(jq -n --arg t "Updated ${ID}" --arg n "Updated content" '{title:$t,note:$n}')
  UPDATED=$(curl -sf -X PUT "${API_BASE}/notes/${ID}" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}" | jq -r '.title // empty')

  if [[ -z "${UPDATED}" ]]; then
    echo "ERROR: Failed to update note ${ID}"
    exit 1
  fi
  echo "NOTE: Update ${ID} — OK"
done

# ── Delete ────────────────────────────────────────────────────────────────────

echo "NOTE: Deleting each note..."
for ID in "${NOTE_IDS[@]}"; do
  MSG=$(curl -sf -X DELETE "${API_BASE}/notes/${ID}" | jq -r '.message // empty')
  if [[ -z "${MSG}" ]]; then
    echo "ERROR: Failed to delete note ${ID}"
    exit 1
  fi
  echo "NOTE: Delete ${ID} — OK"
done

# ── Confirm 404 ───────────────────────────────────────────────────────────────

HTTP=$(curl -s -o /dev/null -w "%{http_code}" "${API_BASE}/notes/${NOTE_IDS[0]}")
if [[ "${HTTP}" != "404" ]]; then
  echo "ERROR: Expected 404 for deleted note, got ${HTTP}"
  exit 1
fi
echo "NOTE: Deleted note returns 404 — OK"

# ── Web app URL ───────────────────────────────────────────────────────────────

cd 02-webapp
WEBSITE_URL=$(terraform output -raw website_url 2>/dev/null || true)
cd ..

echo ""
[ -n "${WEBSITE_URL:-}" ] && echo "NOTE: Web app: ${WEBSITE_URL}index.html"
echo ""