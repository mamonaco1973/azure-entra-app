# Azure Serverless Notes API with Azure Functions, Cosmos DB, and Azure AD B2C

This project delivers a fully automated **serverless CRUD API** on Azure, secured
with **Azure AD B2C** authentication. It uses **Azure Functions**, **Azure Cosmos
DB**, and **Azure Blob Storage**, provisioned entirely with **Terraform** and
deployed with shell scripts — no virtual machines, no manual portal configuration
beyond the one-time B2C tenant setup.

For testing and demonstration purposes, a lightweight **HTML web frontend**
interacts directly with the deployed API, allowing signed-in users to create, view,
update, and delete their own notes from a browser.

![webapp](webapp.png)

This design follows a **serverless microservice architecture** where Azure Functions
handle HTTP routing and JWT validation, Cosmos DB provides fully managed NoSQL
persistence scoped per authenticated user, and Blob Storage hosts the static
frontend.

![diagram](azure-b2c-app.png)

Key capabilities demonstrated:

1. **Authenticated CRUD API** — All five REST endpoints require a valid Azure AD
   B2C access token. The function code validates the JWT signature against B2C's
   JWKS endpoint and rejects unsigned or expired tokens with HTTP 401.
2. **Per-User Data Isolation** — The Cosmos DB partition key `/owner` is set from
   the JWT `sub` claim. Each user can only read and write their own notes — enforced
   at the storage layer, not just the application layer.
3. **PKCE OAuth2 Flow** — The SPA uses the Authorization Code + PKCE flow with no
   client secret. `callback.html` exchanges the authorization code for tokens and
   stores them in `sessionStorage`.
4. **Stateless Compute Layer** — All five operations are handled by a single
   Function App on a Flex Consumption plan — zero idle cost, scales on demand.
5. **Infrastructure as Code (IaC)** — Terraform provisions the Function App, Cosmos
   DB, Blob Storage, and B2C app registration in a repeatable, auditable way.

---

## Authentication Flow

```
1. User clicks "Sign In" in the browser
2. SPA generates PKCE verifier + challenge, stores verifier in sessionStorage
3. Browser redirects to B2C Hosted UI (authorize endpoint)
4. User creates an account or signs in with email + password
5. B2C redirects to callback.html?code=...&state=...
6. callback.html validates state, exchanges code + verifier for tokens
7. access_token, id_token, refresh_token stored in sessionStorage
8. Browser redirects to index.html
9. All API calls include Authorization: Bearer <access_token>
10. Function validates JWT signature via B2C JWKS, extracts sub as owner
11. Cosmos DB queries are scoped to the owner partition key
```

---

## API Endpoints

All endpoints require `Authorization: Bearer <access_token>` and return JSON.

| Method | Path | Purpose | Input | Cosmos DB Operation |
|---|---|---|---|---|
| POST | `/api/notes` | Create a new note | JSON body (`title`, `note`) | `create_item` |
| GET | `/api/notes` | List caller's notes | None (owner from JWT) | `query_items` |
| GET | `/api/notes/{id}` | Get a single note | Path param (`id`) | `read_item` |
| PUT | `/api/notes/{id}` | Update a note | Path param + JSON body | `replace_item` |
| DELETE | `/api/notes/{id}` | Delete a note | Path param (`id`) | `delete_item` |

| Aspect | Behavior |
|---|---|
| Authentication | Azure AD B2C JWT (Bearer token, RS256) |
| Authorization | Owner scoped — callers can only access their own notes |
| Content-Type | `application/json` |
| Unauthenticated | HTTP 401 |
| Not found / wrong owner | HTTP 404 |

### POST /api/notes

**Request:**
```bash
curl -s -X POST https://<func-app>.azurewebsites.net/api/notes \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Note","note":"This is my note"}'
```

**Response (201):**
```json
{
  "id": "2f2d0c5a-9f5f-4d7d-9e2c-1c8a5b8e3c21",
  "title": "Test Note",
  "note": "This is my note"
}
```

### GET /api/notes

**Response (200):**
```json
{
  "items": [
    {
      "id": "2f2d0c5a-9f5f-4d7d-9e2c-1c8a5b8e3c21",
      "title": "Test Note",
      "note": "This is my note",
      "created_at": "2026-04-10T14:12:09.123456+00:00",
      "updated_at": "2026-04-10T14:12:09.123456+00:00"
    }
  ]
}
```

### GET /api/notes/{id}

```bash
curl -s https://<func-app>.azurewebsites.net/api/notes/<id> \
  -H "Authorization: Bearer <access_token>"
```

### PUT /api/notes/{id}

```bash
curl -s -X PUT https://<func-app>.azurewebsites.net/api/notes/<id> \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"title":"Updated Title","note":"Updated content"}'
```

### DELETE /api/notes/{id}

```bash
curl -s -X DELETE https://<func-app>.azurewebsites.net/api/notes/<id> \
  -H "Authorization: Bearer <access_token>"
```

---

## Prerequisites

### Tools

* [An Azure Account](https://portal.azure.com/)
* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
* [Terraform](https://developer.hashicorp.com/terraform/install)
* [jq](https://jqlang.github.io/jq/download/)

### One-time B2C setup (Azure Portal)

The B2C tenant and user flow must be created manually before the first deploy.
Everything else is automated.

**1. Create an Azure AD B2C tenant**

In the Azure Portal, search "Azure AD B2C" → Create a new Azure AD B2C Tenant.
Note the **tenant domain prefix** (e.g. `mynotesb2c`) and the **tenant ID (GUID)**
from the tenant overview.

**2. Create a sign-up/sign-in user flow**

Switch your portal directory to the B2C tenant. Go to **Azure AD B2C → User flows
→ New user flow → Sign up and sign in → Recommended**. Name it `signupsignin`
(Azure prepends `B2C_1_`, giving `B2C_1_signupsignin`). Select **Email signup**,
collect **Email Address**, return claims **Email Addresses** and **User's Object ID**.

**3. Create a service principal in the B2C tenant**

Still in the B2C tenant, go to **App registrations → New registration**. After
creation, add a client secret. Grant the app `Application.ReadWrite.All` on
**Microsoft Graph** (application permission, not delegated) and click
**Grant admin consent**. Note the client ID and secret.

### Required environment variables

```bash
# Azure subscription
export ARM_CLIENT_ID="..."
export ARM_CLIENT_SECRET="..."
export ARM_SUBSCRIPTION_ID="..."
export ARM_TENANT_ID="..."

# Azure AD B2C
export B2C_TENANT_ID="..."          # GUID of the B2C tenant
export B2C_TENANT_NAME="mynotesb2c" # Domain prefix only (no .onmicrosoft.com)
export B2C_POLICY_NAME="B2C_1_signupsignin"
export B2C_SP_CLIENT_ID="..."       # App registered IN the B2C tenant
export B2C_SP_CLIENT_SECRET="..."
```

---

## Download this Repository

```bash
git clone https://github.com/mamonaco1973/azure-b2c-app.git
cd azure-b2c-app
```

## Build the Code

Run [check_env.sh](check_env.sh) to validate your environment, then run
[apply.sh](apply.sh) to provision all infrastructure and deploy the application.

```bash
~/azure-b2c-app$ ./apply.sh
NOTE: All required commands are available.
NOTE: All required environment variables are set.
NOTE: Successfully logged into Azure.
NOTE: Deploying infrastructure...

Initializing the backend...
```

`apply.sh` performs the following steps in order:

1. Runs `check_env.sh` — validates CLI tools, env vars, and Azure authentication
2. Deploys `01-functions` — resource group, Cosmos DB, Function App, Blob Storage
   web account, and B2C app registration (with redirect URI pointed at the storage URL)
3. Packages and deploys the Python function code via `az functionapp deployment source config-zip`
4. Generates `02-webapp/config.json` with the B2C authority, client ID, redirect URI,
   and API base URL
5. Copies `index.html.tmpl` → `index.html`
6. Deploys `02-webapp` — uploads `index.html`, `callback.html`, and `config.json`
   to the `$web` container
7. Runs `validate.sh` to print the web app URL

To tear down all resources:

```bash
./destroy.sh
```

---

## Build Results

When the deployment completes, the following resources are created in a single
resource group `notes-b2c-rg`:

- **Azure Cosmos DB:**
  - Account with Session consistency and GlobalDocumentDB kind
  - Database `notes` with container `notes`
  - Partition key `/owner` — set to the authenticated user's `sub` claim
  - Item ID is a UUID

- **Azure Functions:**
  - Flex Consumption plan (`FC1`) — serverless, pay-per-execution
  - Python 3.11 runtime with Python v2 programming model
  - Single `function_app.py` implementing all five routes
  - CORS restricted to the Blob Storage origin
  - B2C tenant name, tenant ID, policy, and client ID injected via app settings
  - JWT validation (`PyJWT` + `cryptography`) performed in function code

- **Static Web App (Blob Storage):**
  - Storage account `notesb2cweb<suffix>` with static website hosting
  - `index.html`, `callback.html`, and `config.json` in the `$web` container
  - PKCE OAuth2 flow — no client secret exposed in the browser
  - Tokens stored in `sessionStorage`

- **Azure AD B2C:**
  - App registration `notes-b2c-app` (SPA platform, no client secret)
  - Redirect URI: `https://<storage>.z1.web.core.windows.net/callback.html`
  - Managed by Terraform via the `azuread` provider pointed at the B2C tenant

---

## Project Structure

```
azure-b2c-app/
├── 01-functions/
│   ├── code/
│   │   ├── function_app.py    # 5 Azure Functions; JWT validated in validate_token()
│   │   ├── requirements.txt   # azure-functions, azure-cosmos, PyJWT, cryptography, requests
│   │   └── host.json          # Extension bundle v4
│   ├── b2c.tf                 # azuread_application (SPA, PKCE, redirect URI)
│   ├── cosmosdb.tf            # Cosmos DB account, database, container (/owner partition)
│   ├── functions.tf           # Storage, service plan, Function App + B2C env vars
│   ├── main.tf                # azurerm + azuread providers, resource group, random suffix
│   ├── outputs.tf             # URLs, storage name, B2C client ID + authority
│   ├── storage.tf             # Web hosting storage account (here so URL is known for B2C redirect URI)
│   └── variables.tf           # location + B2C variables
├── 02-webapp/
│   ├── callback.html          # PKCE auth code exchange; stores tokens in sessionStorage
│   ├── config.json            # Generated at deploy time — not committed
│   ├── index.html.tmpl        # SPA with auth gate, PKCE sign-in/out, JWT in all API calls
│   ├── main.tf                # azurerm provider + web_storage_name variable
│   └── storage.tf             # Blob uploads only (index.html, callback.html, config.json)
├── apply.sh                   # Full deployment orchestrator (4 phases)
├── destroy.sh                 # Reverse teardown
├── validate.sh                # Prints web app URL
└── check_env.sh               # Validates tools, B2C env vars, and Azure auth
```
