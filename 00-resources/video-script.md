# Video Script — Serverless CRUD API on Azure with Functions and Cosmos DB

---

## Introduction

[ Screen recording of the Notes Demo web app — creating, editing, and deleting notes in the browser ]

"Do you need a working serverless CRUD API on Azure?

[ Architecture diagram — walk through it left to right: browser, storage account, Function App, Cosmos DB ]

"In this project we build a fully serverless notes API using Azure Functions, Cosmos DB, and storage account — all provisioned with Terraform and deployed with a single script."

[ index.html in the browser — note list on the left, editor on the right ]

"The frontend is a static web app hosted on storage account. It talks to a Python Function App that handles all four operations — Create, Read, Update, and Delete — backed by Cosmos DB."

[ Terminal running apply.sh — Terraform output flying by, ending with the website URL ]

"Follow along and in minutes you'll have a working CRUD API running in Azure."

---

## Architecture

[ Full diagram ]

"Let's walk through the architecture before we build."

[ Highlight browser and storage account ]

"The user opens a static web page — just an HTML file served directly from an Azure storage account."

[ Highlight Function App ]

"The frontend talks to an Azure Function App over HTTP. One Python file handles all the routes — POST to create, GET to list, GET by ID, PUT to update, DELETE to remove."

[ Highlight Cosmos DB ]

"The backend stores data in Cosmos DB. Each note is a JSON document. The Function App connects using the Cosmos DB endpoint."

[ Highlight Flex Consumption plan ]

"The Function App runs on the Flex Consumption plan — FC1. Pay per execution, scales to zero when idle."

[ Full diagram ]

"Two resource groups, one script to deploy. Let's build it."

---

## Build the Code

[ Terminal — running ./apply.sh ]

"The whole deployment is one script — apply.sh. Three phases."

[ Terminal — Phase 1: Terraform apply ]

"Phase one: Terraform provisions the Function App and Cosmos DB — storage account for the code, the database, the app itself, all wired together."

[ Terminal — Phase 2: zip deploy ]

"Phase two: the Python code gets zipped and pushed to Azure with --build-remote. Dependencies install in the cloud — no local Python needed."

[ Terminal — Phase 3: webapp Terraform ]

"Phase three: envsubst injects the Function App URL into the HTML template. Terraform drops the file into storage account and the site is live."

[ Terminal — deployment complete, URLs printed ]

"API URL. Website URL. Done."

---

## Build Results

[ Azure Portal — Resource Groups ]

"Two resource groups — one for the Function App and Cosmos DB, one for the web frontend."

[ Azure Portal — Function App, Flex Consumption plan visible ]

"Function App on FC1. Python 3.11. Cosmos DB connection settings in app settings."

[ Azure Portal — Cosmos DB container ]

"Cosmos DB with a notes container. Partition key is owner."

[ Azure Portal — storage account, $web container ]

"Static website enabled. index.html in the $web container, ready to serve."

[ Browser — Notes Demo loads ]

"Open the URL. The app is live."

---

## Demo

[ Browser — Notes Demo, empty note list ]

"The app loads and calls the list endpoint. No notes yet."

[ Clicking New — modal opens, typing a title, clicking Create ]

"New note. Give it a title. Create it — POST /api/notes. ID comes back, list refreshes."

[ Clicking the note in the list ]

"Click it. GET /api/notes/{id}. Content loads into the editor."

[ Editing and clicking Save ]

"Edit and save. PUT /api/notes/{id}. Written back to Cosmos DB."

[ Clicking Delete ]

"Delete. DELETE /api/notes/{id}. Gone."

[ Browser — empty list ]

"Create, read, update, delete — serverless on Azure. One script to deploy, one script to destroy."

---
