#Azure #Serverless #AzureFunctions #CosmosDB #EntraExternalID #Terraform #Python #CRUD

*Secure a Serverless API on Azure (Function App + Entra External ID)*

Add real user authentication to a serverless notes API on Azure using Microsoft Entra External ID and in-code JWT validation — all provisioned with Terraform and deployed with a single script. The backend runs on a Flex Consumption (FC1) Function App with Python, Cosmos DB stores the data with per-user partitioning, and a static Blob Storage frontend handles the Entra sign-in flow.


WHAT YOU'LL LEARN
• Provisioning an Entra External ID app registration using the azuread Terraform provider
• Validating Entra JWTs in Python directly inside the Function App with in-instance JWKS caching
• Using the JWT sub claim as the Cosmos DB partition key to enforce per-user data isolation
• Associating an Entra app registration with a user flow via the Microsoft Graph API
• Locking Function App CORS to a specific Blob Storage origin
• Generating runtime config (config.json) at deploy time from Terraform outputs

INFRASTRUCTURE DEPLOYED
• Azure Function App (Flex Consumption / FC1, Python 3.11, 5 HTTP routes, JWT validated in code)
• Cosmos DB account with SQL API database and container (partition key: /owner)
• Entra External ID app registration (SPA platform, no client secret, redirect URI wired to Blob Storage)
• Storage account for function code zip deployment
• Storage account hosting a static SPA ($web container: index.html, callback.html, config.json)

GitHub
https://github.com/mamonaco1973/azure-entra-app

README
https://github.com/mamonaco1973/azure-entra-app/blob/main/README.md

TIMESTAMPS
00:00 Introduction
00:16 Architecture
00:39 Build the Code
02:31 Build Results
03:21 Demo
