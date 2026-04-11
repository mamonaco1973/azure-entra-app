import azure.functions as func
import json
import uuid
import os
import requests
from datetime import datetime, timezone
from azure.cosmos import CosmosClient, exceptions
import jwt
from jwt.algorithms import RSAAlgorithm

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

ENDPOINT    = os.environ["COSMOS_ENDPOINT"]
KEY         = os.environ["COSMOS_KEY"]
DATABASE    = os.environ["COSMOS_DATABASE"]
CONTAINER   = os.environ["COSMOS_CONTAINER"]

ENTRA_TENANT    = os.environ["ENTRA_TENANT_NAME"]
ENTRA_TENANT_ID = os.environ["ENTRA_TENANT_ID"]
CLIENT_ID       = os.environ["ENTRA_CLIENT_ID"]

# Cached per function-app instance (warm invocations skip the JWKS fetch).
_jwks_cache = None


def _get_jwks():
    global _jwks_cache
    if _jwks_cache is None:
        url = (
            f"https://{ENTRA_TENANT}.ciamlogin.com/{ENTRA_TENANT_ID}"
            f"/discovery/v2.0/keys"
        )
        _jwks_cache = requests.get(url, timeout=5).json()
    return _jwks_cache


def validate_token(req: func.HttpRequest):
    """Returns the owner ID (sub claim) if the Bearer token is valid, else None."""
    auth = req.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return None
    token = auth[7:]
    try:
        jwks = _get_jwks()
        header = jwt.get_unverified_header(token)
        key_data = next((k for k in jwks["keys"] if k["kid"] == header["kid"]), None)
        if key_data is None:
            return None
        public_key = RSAAlgorithm.from_jwk(json.dumps(key_data))
        claims = jwt.decode(
            token,
            public_key,
            algorithms=["RS256"],
            audience=CLIENT_ID,
        )
        return claims.get("sub") or claims.get("oid")
    except Exception:
        return None


def get_container():
    client = CosmosClient(ENDPOINT, KEY)
    return client.get_database_client(DATABASE).get_container_client(CONTAINER)


def resp(status, body):
    return func.HttpResponse(
        json.dumps(body),
        status_code=status,
        mimetype="application/json",
        headers={"Content-Type": "application/json"},
    )


# ── POST /api/notes ────────────────────────────────────────────────────────────

@app.route(route="notes", methods=["POST"])
def create_note(req: func.HttpRequest) -> func.HttpResponse:
    owner = validate_token(req)
    if not owner:
        return resp(401, {"error": "Unauthorized"})

    try:
        body = req.get_json()
    except ValueError:
        return resp(400, {"error": "Invalid JSON"})

    title = body.get("title", "").strip()
    note  = body.get("note",  "").strip()
    if not title:
        return resp(400, {"error": "title is required"})

    now  = datetime.now(timezone.utc).isoformat()
    item = {
        "id":         str(uuid.uuid4()),
        "owner":      owner,
        "title":      title,
        "note":       note,
        "created_at": now,
        "updated_at": now,
    }

    get_container().create_item(body=item)
    return resp(201, {"id": item["id"], "title": item["title"], "note": item["note"]})


# ── GET /api/notes ─────────────────────────────────────────────────────────────

@app.route(route="notes", methods=["GET"])
def list_notes(req: func.HttpRequest) -> func.HttpResponse:
    owner = validate_token(req)
    if not owner:
        return resp(401, {"error": "Unauthorized"})

    items = list(get_container().query_items(
        query="SELECT c.id, c.title, c.note, c.created_at, c.updated_at FROM c WHERE c.owner = @owner",
        parameters=[{"name": "@owner", "value": owner}],
        enable_cross_partition_query=False,
    ))
    return resp(200, {"items": items})


# ── GET /api/notes/{id} ────────────────────────────────────────────────────────

@app.route(route="notes/{id}", methods=["GET"])
def get_note(req: func.HttpRequest) -> func.HttpResponse:
    owner = validate_token(req)
    if not owner:
        return resp(401, {"error": "Unauthorized"})

    note_id = req.route_params.get("id")
    try:
        item = get_container().read_item(item=note_id, partition_key=owner)
        return resp(200, {
            "id":         item["id"],
            "title":      item["title"],
            "note":       item["note"],
            "created_at": item["created_at"],
            "updated_at": item["updated_at"],
        })
    except exceptions.CosmosResourceNotFoundError:
        return resp(404, {"error": "Note not found"})


# ── PUT /api/notes/{id} ────────────────────────────────────────────────────────

@app.route(route="notes/{id}", methods=["PUT"])
def update_note(req: func.HttpRequest) -> func.HttpResponse:
    owner = validate_token(req)
    if not owner:
        return resp(401, {"error": "Unauthorized"})

    note_id = req.route_params.get("id")
    try:
        body = req.get_json()
    except ValueError:
        return resp(400, {"error": "Invalid JSON"})

    container = get_container()
    try:
        item = container.read_item(item=note_id, partition_key=owner)
    except exceptions.CosmosResourceNotFoundError:
        return resp(404, {"error": "Note not found"})

    item["title"]      = body.get("title", item["title"]).strip()
    item["note"]       = body.get("note",  item["note"]).strip()
    item["updated_at"] = datetime.now(timezone.utc).isoformat()

    container.replace_item(item=note_id, body=item)
    return resp(200, {
        "id":         item["id"],
        "title":      item["title"],
        "note":       item["note"],
        "updated_at": item["updated_at"],
    })


# ── DELETE /api/notes/{id} ─────────────────────────────────────────────────────

@app.route(route="notes/{id}", methods=["DELETE"])
def delete_note(req: func.HttpRequest) -> func.HttpResponse:
    owner = validate_token(req)
    if not owner:
        return resp(401, {"error": "Unauthorized"})

    note_id = req.route_params.get("id")
    try:
        get_container().delete_item(item=note_id, partition_key=owner)
    except exceptions.CosmosResourceNotFoundError:
        pass  # idempotent
    return resp(200, {"message": "Note deleted"})
