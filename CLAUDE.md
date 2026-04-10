# CLAUDE.md — azure-crud-example

## Project Overview

Terraform + Azure Functions project that deploys a serverless CRUD API for
managing "notes", backed by Azure Cosmos DB. A static frontend is hosted on
Azure Blob Storage. This is a port of `aws-crud-example` (Lambda + DynamoDB + S3).

## Architecture

```
01-functions/          Function App + Cosmos DB
  code/
    function_app.py    All 5 HTTP-triggered functions (Python v2 model)
    requirements.txt   azure-functions, azure-cosmos
    host.json          Extension bundle config
  main.tf              Provider, resource group (notes-rg), random suffix
  cosmosdb.tf          Cosmos DB account → database → container
  functions.tf         Storage account, service plan (Y1), Function App, code deploy
  outputs.tf           function_app_name, function_app_url, resource_group_name

02-webapp/             Static frontend
  index.html.tmpl      Template — ${API_BASE} substituted by apply.sh
  main.tf              Provider, resource group (notes-webapp-rg)
  storage.tf           Storage account, static website, index.html blob
```

### Deployment Order

1. `01-functions` — Cosmos DB + Function App (Terraform + zip deploy)
2. `02-webapp` — Blob Storage static site (Terraform)

### Key Resources

| Resource | Value |
|---|---|
| Resource group (backend) | `notes-rg` |
| Resource group (frontend) | `notes-webapp-rg` |
| Location | `East US` |
| Cosmos DB kind | `GlobalDocumentDB` (SQL API) |
| Cosmos DB consistency | `Session` |
| Container throughput | `400 RU/s` |
| Partition key | `/owner` (hardcoded value: `"global"`) |
| Item ID | UUID (string) |
| Function runtime | Python 3.11 |
| Service plan SKU | `B1` (Basic) |
| Function auth level | `ANONYMOUS` |
| API base path | `https://<func-app>.azurewebsites.net/api` |

## API Endpoints

| Method | Route | Function |
|---|---|---|
| POST | `/api/notes` | `create_note` |
| GET | `/api/notes` | `list_notes` |
| GET | `/api/notes/{id}` | `get_note` |
| PUT | `/api/notes/{id}` | `update_note` |
| DELETE | `/api/notes/{id}` | `delete_note` |

## Common Commands

```bash
# Validate environment (checks az, terraform, jq in PATH + Azure auth)
./check_env.sh

# Deploy everything
./apply.sh

# Tear down
./destroy.sh

# Validate all CRUD endpoints
./validate.sh
```

### Manual API Testing

```bash
# Get function app URL from Terraform
cd 01-functions && API_BASE=$(terraform output -raw function_app_url) && cd ..

# Create
curl -s -X POST "${API_BASE}/notes" \
  -H "Content-Type: application/json" \
  -d '{"title":"Hello","note":"World"}'

# List
curl -s "${API_BASE}/notes" | jq .

# Get
curl -s "${API_BASE}/notes/<id>" | jq .

# Update
curl -s -X PUT "${API_BASE}/notes/<id>" \
  -H "Content-Type: application/json" \
  -d '{"title":"Updated","note":"Content"}'

# Delete
curl -s -X DELETE "${API_BASE}/notes/<id>" | jq .
```

## How Code Deployment Works

Terraform creates the Function App infrastructure, then a `null_resource` in
`functions.tf` runs `az functionapp deployment source config-zip` using a ZIP
produced by the `archive_file` data source. The `null_resource` re-triggers
whenever `data.archive_file.function_code.output_sha256` changes.

## Cosmos DB Notes

- The `id` field in Cosmos DB is the primary key within a partition — it maps
  directly to the note UUID.
- All notes share `owner = "global"` (hardcoded), so all items are in one
  logical partition.
- `read_item(item=id, partition_key="global")` is used for single-item lookups
  (O(1), no cross-partition query needed).
- `query_items` with `enable_cross_partition_query=False` is used for list
  (all items are in the same partition).

## AWS vs Azure Mapping

| AWS | Azure |
|---|---|
| Lambda (5 separate functions) | Azure Functions v2 (single `function_app.py`) |
| API Gateway HTTP API | Azure Functions HTTP triggers |
| DynamoDB | Cosmos DB SQL API |
| S3 static website | Blob Storage `$web` container + static website |
| IAM role per function | Cosmos DB key in Function App app settings |
| `boto3` | `azure-cosmos` |
