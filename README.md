# Azure Three-Tier App + Terraform + GitHub Actions Plan

## Goal

Build a promotion-ready engineering showcase that demonstrates:

* A React web client
* A .NET API
* A PostgreSQL database
* Terraform-based infrastructure as code
* GitHub Actions CI/CD
* Three environments: Dev, Test, Prod
* Ephemeral per-branch Dev deployments
* Manual promotion to Prod
* Blue/green deployment in Prod
* Unit, integration, and system tests

## Recommended Target Architecture

### App tier choices

For this project, use:

* **Web client:** React + Vite, packaged as a container and deployed to Azure Container Apps
* **API:** ASP.NET Core Web API, packaged as a container and deployed to Azure Container Apps
* **DB:** Azure Database for PostgreSQL Flexible Server with private networking

### Why this is the right fit

This gives you:

* A modern containerized deployment model
* Cleaner parity between web and API tiers
* Better support for controlled blue/green in Prod
* A stronger enterprise story than a simple static web app + basic API deployment
* A clean Terraform story across all tiers

## Delivery Phases

### Phase 1 — Build the app locally

1. Create a monorepo with:

   * `src/web`
   * `src/api`
   * `tests/unit`
   * `tests/integration`
   * `tests/system`
   * `infra/terraform`
   * `.github/workflows`
2. Build the React UI
3. Build the .NET API
4. Connect API to Postgres locally with Docker Compose
5. Add tests
6. Containerize the web and API
7. Prove local end-to-end startup works

### Phase 2 — Build Azure base infrastructure

1. Resource group strategy
2. Virtual network and subnets
3. Private DNS
4. Azure Container Registry
5. Azure Container Apps environment
6. PostgreSQL Flexible Server with private access
7. Key Vault / secrets approach
8. Monitoring foundation

### Phase 3 — Terraform structure for 3 environments

1. Reusable modules
2. Environment-specific variable files
3. Remote state
4. Separate state per environment
5. Branch-derived ephemeral Dev stacks

### Phase 4 — CI/CD with GitHub Actions

1. PR validation
2. Build/test workflow
3. Terraform plan/apply workflow
4. App deploy workflow
5. Environment approvals
6. Automatic cleanup for expired branch environments

### Phase 5 — Prod blue/green rollout

1. Keep two prod revisions live
2. Route traffic to blue or green
3. Run smoke checks
4. Switch traffic fully when healthy
5. Roll back quickly by restoring traffic to prior revision

---

## Environment Strategy

### Dev

* Every feature branch creates its own isolated Dev deployment
* Naming pattern example: `dev-<sanitized-branch-name>`
* Each branch environment gets TTL metadata
* Branch environments are deleted when:

  * the branch is merged, or
  * the environment reaches 30 days old

### Test

* A shared integration environment
* Deploys after code is merged from a feature branch into the `test` branch
* Used for full integration and system testing

### Prod

* Only updated from the `main` branch
* Requires:

  * PR approval into `main`
  * GitHub Environment approval for deployment
* Uses blue/green deployment strategy

## Recommended Git Branching Model

* `feature/*` → personal or team development branches
* `test` → integration / pre-production validation
* `main` → production source of truth

## Promotion flow

1. Push to `feature/my-work`
2. GitHub Actions deploys ephemeral Dev environment for that branch
3. Open PR from `feature/my-work` to `test`
4. After merge to `test`, pipeline deploys shared Test environment
5. Validate in Test
6. Open PR from `test` to `main`
7. After approval and merge, Prod deployment workflow starts
8. Prod deploy pauses for manual approval in GitHub Environment
9. Once approved, blue/green deployment executes

## What “manual merge to Prod” should mean

Do **not** manually copy files or manually apply Terraform.
Instead:

* Use a pull request from `test` to `main`
* Protect `main` with required reviewers
* Require successful checks before merge
* Configure the Prod GitHub Environment with required approvers
* After merge, the Prod workflow runs but cannot proceed until approval is granted

That gives you both:

* controlled code promotion, and
* controlled deployment approval

---

## Terraform Design

### Folder shape

```text
infra/terraform/
  modules/
    resource_group/
    network/
    acr/
    container_apps_env/
    web_app/
    api_app/
    postgres/
    monitoring/
    github_oidc_identity/
  envs/
    dev/
    test/
    prod/
  global/
```

### Recommended approach

Use:

* **shared reusable modules** for all resources
* **one root stack per environment**
* **environment-specific tfvars**
* **remote state separated by environment**

### How to support ephemeral Dev branch environments

Use one of these patterns:

#### Better learning/demo pattern

* One Terraform root for branch Dev environments
* Inputs include:

  * `environment = dev`
  * `branch_name`
  * `ttl_days`
  * `is_ephemeral = true`
* Resource names include the branch suffix
* A cleanup workflow destroys old branch stacks automatically

#### Why this is better than hardcoding 3 folders only

Because your Dev requirement is not a single static environment. It is a dynamic environment factory.

---

## Testing Strategy

### Unit tests

* React component tests
* .NET service/controller/domain tests

### Integration tests

* API + database integration tests
* Run against local Docker Compose during CI
* Later run against Test environment after deploy

### System tests

* End-to-end browser tests against deployed environment
* Example tooling: Playwright
* Run on ephemeral Dev and shared Test

### Promotion gates

* Feature branch cannot deploy if build/tests fail
* Test cannot promote unless integration/system tests pass
* Prod cannot deploy unless approvals are satisfied and smoke tests pass

---

## Security / Enterprise Story

For promotion-level credibility, include:

* GitHub Actions to Azure auth using OIDC, not long-lived secrets
* Separate state per environment
* Private database networking
* Secret values stored in Azure-managed secret store or environment secret mechanism
* Least-privilege identities
* Branch protection rules
* Manual approvals for Prod
* Health checks and rollback path
* Diagnostic settings / logs / metrics

---

## Base Infrastructure Direction

When we move to Azure base infrastructure, build this next:

1. Resource group conventions
2. VNet address space
3. Subnets for:

   * Container Apps environment
   * PostgreSQL delegated subnet
   * optional private endpoints / future expansion
4. Private DNS zones
5. Container registry
6. Container Apps environment
7. PostgreSQL Flexible Server
8. Observability resources

---

## Phase 1 App Scope

Start with a small but credible business domain.
Recommended example:

* **Work Intake / Service Request Tracker**

Why this works:

* Enterprise-friendly
* Easy to explain to leadership
* Supports CRUD + filtering + authentication later
* Gives you enough surface area for meaningful tests

### Suggested MVP features

* Create request
* View request list
* View request details
* Update status
* Search/filter requests
* Health endpoint for API
* Readiness check for app tier

### Data model

`service_requests`

* `id`
* `title`
* `description`
* `requestor_email`
* `priority`
* `status`
* `created_at`
* `updated_at`

---

## What I recommend we do first

### First implementation step

Build the app in this order:

1. Define the domain and API contract
2. Scaffold the .NET API
3. Add Postgres persistence locally
4. Scaffold React UI
5. Connect UI to API
6. Add tests
7. Containerize

### Immediate next deliverables

We should produce, in order:

1. The monorepo folder structure
2. The app architecture decision record
3. The initial domain model
4. The API endpoint list
5. The local Docker Compose setup
6. The test plan

## Recommendation

Use this exact technology stack:

* React + Vite
* ASP.NET Core Web API
* Entity Framework Core + Npgsql
* PostgreSQL
* Playwright for system tests
* xUnit for .NET tests
* Vitest + React Testing Library for React tests
* Docker Compose for local integration
* Terraform for Azure IaC
* GitHub Actions for CI/CD

## Next session starting point

Start with:

* monorepo layout
* app use case definition
* API contract
* local development architecture


Yes — and I already turned your answers into a working plan we can refine as we go.

My recommendation is to build this on Azure Container Apps for the React client and the .NET API, with Azure Database for PostgreSQL Flexible Server for the database. That gives you a stronger enterprise story for your promotion case because Container Apps supports VNet-based environments, revisions, traffic splitting, and deployment labels, which line up well with controlled releases and blue/green in Prod. App Service deployment slots are a valid fallback, but for your goals, Container Apps is the better fit. ([Microsoft Learn][1])

For the database, use PostgreSQL Flexible Server with private access inside your network design. Azure’s current guidance for private networking uses delegated subnets plus Private DNS, and when you provision it through Terraform/API you need a Private DNS zone ending in `.postgres.database.azure.com`. ([Microsoft Learn][2])

For CI/CD, use GitHub Actions authenticating to Azure through OIDC instead of storing long-lived Azure secrets in GitHub. Microsoft documents federated credentials for GitHub Actions, and GitHub environments support required reviewers so a Prod deployment job can pause for approval before it starts. ([Microsoft Learn][3])

Here is the shape I want you to use.

First, the environment model:

* Feature branches create ephemeral Dev environments named from the branch, such as `dev-feature-foo`.
* Those Dev environments auto-expire after 30 days or get destroyed when the branch is merged.
* A shared `test` environment gets deployed from merges into a `test` branch.
* Prod deploys only from `main`, with a manual approval gate.

The part you said was fuzzy — “manual merged to Prod” — should work like this:

1. A developer merges `feature/*` into `test`.
2. GitHub Actions deploys the shared Test environment.
3. When Test is good, you open a PR from `test` to `main`.
4. Branch protection on `main` requires review and passing checks.
5. After merge to `main`, the Prod workflow starts.
6. The Prod job references the GitHub `production` environment, so it waits for an approver before deployment begins. ([GitHub Docs][4])

That gives you both code promotion control and deployment control, which is exactly what leadership wants to see.

The build order should be:

1. App first
   Build a small but credible business app. I recommend a service request tracker or work intake app because it feels enterprise-real without becoming huge.

2. Base Azure infrastructure second
   Resource groups, VNet, subnets, private DNS, Container Registry, Container Apps environment, PostgreSQL, and monitoring foundation.

3. Terraform structure third
   Reusable modules plus separate environment roots. Dev needs a special pattern because it is not one environment — it is a branch-driven environment factory.

4. Pipelines fourth
   Validation, build/test, Terraform plan/apply, app deploy, promotion, cleanup.

5. Prod blue/green fifth
   Blue/green for the web and API tiers. Do not try to blue/green the database for version 1. Use one Prod database and require backward-compatible migrations.

For the app phase, this is the exact stack I recommend:

* React + Vite
* ASP.NET Core Web API
* Entity Framework Core + Npgsql
* PostgreSQL
* Docker Compose for local integration
* xUnit for .NET tests
* Vitest + React Testing Library for the UI
* Playwright for system tests

For the app itself, keep the MVP small:

* Create request
* View request list
* View request details
* Update request status
* Search and filter
* API health endpoint
* Readiness endpoint

That is enough to prove:

* frontend and backend separation
* database persistence
* environment-based configuration
* test automation
* containerization
* deployability

The repo shape should look like this:

* `src/web`
* `src/api`
* `tests/unit`
* `tests/integration`
* `tests/system`
* `infra/terraform`
* `.github/workflows`

And the Terraform shape should look like this:

* `infra/terraform/modules/...`
* `infra/terraform/envs/test`
* `infra/terraform/envs/prod`
* `infra/terraform/envs/dev-ephemeral`

The reason I am separating `dev-ephemeral` from `test` and `prod` is that your Dev requirement is dynamic. Test and Prod are stable environments. Dev is an environment factory.

The strongest promotion-ready talking points in this design are:

* branch-based ephemeral environments
* private database networking
* Terraform modules and separated state
* OIDC-based Azure auth from GitHub
* manual approval before Prod
* blue/green rollout in Prod
* unit, integration, and system test gates
* fast rollback by switching traffic back to the prior good revision in Prod for the app tiers. ([Microsoft Learn][5])

Now that we’re starting with the app, the next concrete step should be this: define the business domain, the data model, and the first API contract before writing any Terraform.

[1]: https://learn.microsoft.com/en-us/azure/container-apps/vnet-custom?utm_source=chatgpt.com "Integrate a virtual network with an Azure Container Apps ..."
[2]: https://learn.microsoft.com/en-us/azure/postgresql/network/concepts-networking-private?utm_source=chatgpt.com "Network with private access (virtual network integration) for ..."
[3]: https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect?utm_source=chatgpt.com "Use the Azure Login action with OpenID Connect"
[4]: https://docs.github.com/actions/deployment/targeting-different-environments/using-environments-for-deployment?utm_source=chatgpt.com "Managing environments for deployment"
[5]: https://learn.microsoft.com/en-us/azure/container-apps/traffic-splitting?utm_source=chatgpt.com "Traffic splitting in Azure Container Apps"

---

## Remaining Work & Execution Guide

> **For the AI agent resuming this session**: This section is a self-contained execution guide. Everything needed to finish the project is documented here inline. Read it fully before taking action. Do not skip steps — they are ordered by dependency.

---

### Current State (last updated 2026-04-18)

Phases 1–4 are complete with the following exceptions documented in the steps below. Phase 5 (blue/green) has not been started.

#### What is fully done

- App: React + Vite frontend, ASP.NET Core API, PostgreSQL, Docker Compose local dev
- Tests: Vitest unit, xUnit unit, Testcontainers integration, Playwright system (`./run-tests.sh`)
- EF Core migrations: `InitialCreate` migration exists; API uses `Database.Migrate()` at startup
- Terraform: modules + dev/test/prod envs with remote state in Azure Blob Storage
- Dev and test environments: live and verified
- OIDC service principals: created, roles assigned, federated credentials configured
- GitHub secrets: all 5 set
- Wildcard TLS cert `*.dev.todo.reneriosleon.com`: issued, stored in KV, imported into dev CAE
- All 6 GitHub Actions workflow files: committed and pushed to `main`
- Certbot venv (local Mac only): `~/certbot-venv` using Python 3.12

#### Azure resource inventory

| Resource | Name | Resource Group |
|---|---|---|
| Dev Container Apps Environment | `cae-todo-dev` | `rg-todo-dev-eastus2` |
| Dev Container Registry | `acrtododeva8ca4a` | `rg-todo-dev-eastus2` |
| Dev Key Vault | `kv-todo-dev-a8ca4a` | `rg-todo-dev-eastus2` |
| Dev PostgreSQL | `psql-todo-dev-a8ca4a` | `rg-todo-dev-eastus2` |
| Dev CAE default domain | `calmrock-ca361d2e.eastus2.azurecontainerapps.io` | — |
| Test Container Apps Environment | `cae-todo-test` | `rg-todo-test-eastus2` |
| Test Container Registry | `acrtodotesta8ca4a` | `rg-todo-test-eastus2` |
| Test Key Vault | `kv-todo-test-a8ca4a` | `rg-todo-test-eastus2` |
| Test PostgreSQL | `psql-todo-test-a8ca4a` | `rg-todo-test-eastus2` |
| Prod | **DESTROYED — must be recreated via `terraform apply`** | `rg-todo-prod-eastus2` (does not exist) |
| DNS Zone | `reneriosleon.com` | `rg-dns` |
| Terraform remote state storage | `sttodotfstatea8ca4a` | `rg-todo-tfstate` |

#### OIDC service principals

| SP Name | App ID | Scope |
|---|---|---|
| `sp-github-todo-dev` | `cdcf6cb4-07ea-4724-b0dd-69c2163da602` | AcrPush on dev ACR + Contributor on `rg-todo-dev-eastus2` + Key Vault Secrets User on `kv-todo-dev-a8ca4a` |
| `sp-github-todo-test` | `0f40f834-5e2a-4937-9cdc-1e05afd1ee6d` | AcrPush on test ACR + Contributor on `rg-todo-test-eastus2` |
| `sp-github-todo-prod` | `19a2ad1d-380c-4dc0-b43d-7089985c87d7` | Contributor at **subscription level** — must be tightened after prod is recreated (Step 4) |

#### GitHub secrets (all set in `renerios64/todo`)

- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID` = `a8ca4ab0-9527-48d8-8531-6cb6ca6242d1`
- `DEV_AZURE_CLIENT_ID` = `cdcf6cb4-07ea-4724-b0dd-69c2163da602`
- `TEST_AZURE_CLIENT_ID` = `0f40f834-5e2a-4937-9cdc-1e05afd1ee6d`
- `PROD_AZURE_CLIENT_ID` = `19a2ad1d-380c-4dc0-b43d-7089985c87d7`

#### Wildcard TLS certificate

- Domain: `*.dev.todo.reneriosleon.com`
- Issued: 2026-04-18 | Expires: 2026-07-17
- KV secrets: `wildcard-dev-cert-pfx` (base64 PFX) and `wildcard-dev-cert-password` in `kv-todo-dev-a8ca4a`
- Cert name in dev CAE: `wildcard-dev-todo`
- Full cert resource ID (hardcoded in `deploy-dev.yml`):
  `/subscriptions/a8ca4ab0-9527-48d8-8531-6cb6ca6242d1/resourceGroups/rg-todo-dev-eastus2/providers/Microsoft.App/managedEnvironments/cae-todo-dev/certificates/wildcard-dev-todo`
- DNS CNAME: `*.dev.todo` → `calmrock-ca361d2e.eastus2.azurecontainerapps.io` (in zone `reneriosleon.com`, RG `rg-dns`)
- `cert-renew.yml` runs monthly on the 1st. **Critical: must renew before 2026-07-17.**

#### Known local tooling quirk (Mac only)

Homebrew certbot (`/opt/homebrew/bin/certbot`) uses Python 3.14 which has a josepy bug and will crash. Always use the Python 3.12 venv:

```bash
~/certbot-venv/bin/certbot   # correct
/opt/homebrew/bin/certbot    # broken — do not use
```

If the venv is missing, recreate it:

```bash
python3.12 -m venv ~/certbot-venv
~/certbot-venv/bin/pip install certbot certbot-dns-azure "azure-mgmt-dns<9.0.0"
```

Certbot requires sudo on Mac (writes to `/etc/letsencrypt/`). On GitHub Actions Ubuntu runners it does **not** need sudo — use `--config-dir /tmp/letsencrypt --work-dir /tmp/letsencrypt --logs-dir /tmp/letsencrypt`.

---

### Step 1 — Create the GitHub `production` Environment

**Why**: `deploy-prod.yml` uses `environment: production`. GitHub will refuse to run the job until this environment exists with a required reviewer configured.

**How** (browser only — no CLI for this):

1. Go to: <https://github.com/renerios64/todo/settings/environments>
2. Click **New environment**
3. Name it exactly: `production` (all lowercase, matches the workflow file)
4. Under **Required reviewers**, add `renerios64`
5. Click **Save protection rules**

No wait timer is needed. Do not add deployment branch restrictions — `deploy-prod.yml` already filters on `main` branch via the `on.push.branches` trigger.

---

### Step 2 — Fix `git push` credential helper

**Why**: `git push origin main` currently fails with 403 because the macOS keychain has a cached credential for account `reneriosleon` (wrong account). The correct account is `renerios64`.

**How**:

```bash
gh auth setup-git
git push origin main
```

If it still fails, push explicitly with the gh token:

```bash
git push "https://$(gh auth token)@github.com/renerios64/todo.git" main
```

**Important**: Pushing files under `.github/workflows/` requires the `workflow` OAuth scope on the gh token. Check:

```bash
gh auth status
# look for 'workflow' in "Token scopes"
```

If `workflow` scope is missing:

```bash
gh auth refresh -s workflow
# A device code will be shown. Open https://github.com/login/device, enter the code, approve.
# Press Enter in the terminal when complete.
```

---

### Step 3 — Recreate Prod infrastructure via Terraform

**Why**: Prod was fully destroyed. `rg-todo-prod-eastus2` does not exist. `deploy-prod.yml` will fail at `az acr build` because `acrtodoproda8ca4a` does not exist.

**How**:

```bash
az account set --subscription a8ca4ab0-9527-48d8-8531-6cb6ca6242d1
az account show   # verify

cd infra/terraform/envs/prod
terraform init
terraform plan    # review — expect all prod resources to be created fresh
terraform apply
```

Expected resources created:
- `rg-todo-prod-eastus2`
- `acrtodoproda8ca4a` (ACR)
- `cae-todo-prod` (Container Apps Environment)
- `psql-todo-prod-a8ca4a` (PostgreSQL Flexible Server)
- `kv-todo-prod-a8ca4a` (Key Vault)
- `ca-api-todo-prod` and `ca-web-todo-prod` (Container Apps)
- Custom domain bindings for `todo.reneriosleon.com` and `api.todo.reneriosleon.com`

After apply completes, verify:

```bash
az group show --name rg-todo-prod-eastus2 --query properties.provisioningState -o tsv
# Expected: Succeeded
```

---

### Step 4 — Tighten Prod SP role

**Why**: Prod SP currently has Contributor at subscription scope (a temporary workaround because the prod RG didn't exist at SP creation time). This is overprivileged and must be corrected after Step 3 recreates the prod RG.

**How**:

```bash
SUBSCRIPTION=a8ca4ab0-9527-48d8-8531-6cb6ca6242d1
PROD_SP_OID=$(az ad sp show --id 19a2ad1d-380c-4dc0-b43d-7089985c87d7 --query id -o tsv)

# Remove the broad subscription-level assignment
BROAD_ROLE_ID=$(az role assignment list \
  --assignee $PROD_SP_OID \
  --scope /subscriptions/$SUBSCRIPTION \
  --query "[?roleDefinitionName=='Contributor'].id" -o tsv)
az role assignment delete --ids $BROAD_ROLE_ID

# Contributor scoped to prod RG only
az role assignment create \
  --assignee $PROD_SP_OID \
  --role Contributor \
  --scope /subscriptions/$SUBSCRIPTION/resourceGroups/rg-todo-prod-eastus2

# AcrPush on prod ACR
az role assignment create \
  --assignee $PROD_SP_OID \
  --role AcrPush \
  --scope /subscriptions/$SUBSCRIPTION/resourceGroups/rg-todo-prod-eastus2/providers/Microsoft.ContainerRegistry/registries/acrtodoproda8ca4a

# Key Vault Secrets User on prod KV (deploy-prod.yml reads DB conn string from here)
az role assignment create \
  --assignee $PROD_SP_OID \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/$SUBSCRIPTION/resourceGroups/rg-todo-prod-eastus2/providers/Microsoft.KeyVault/vaults/kv-todo-prod-a8ca4a
```

Verify:

```bash
az role assignment list --assignee $PROD_SP_OID --all --query "[].{role:roleDefinitionName,scope:scope}" -o table
# Should show 3 rows: Contributor on RG, AcrPush on ACR, Key Vault Secrets User on KV
# Should NOT show any subscription-level assignment
```

---

### Step 5 — Set branch protection rules

**Why**: The entire promotion model (feature → test → main) depends on preventing direct pushes and requiring checks to pass.

**How** (browser only — go to <https://github.com/renerios64/todo/settings/branches>):

For `main`:
- Click **Add branch protection rule**
- Branch name pattern: `main`
- ✅ Require a pull request before merging
- ✅ Require approvals: **1**
- ✅ Require status checks to pass before merging
  - Search for and add: `pr-validation` (the job name defined in `.github/workflows/pr.yml`)
- ✅ Require branches to be up to date before merging
- ✅ Do not allow bypassing the above settings
- Save

For `test`:
- Click **Add branch protection rule**
- Branch name pattern: `test`
- ✅ Require a pull request before merging
- ✅ Require status checks to pass: `pr-validation`
- Save

---

### Step 6 — End-to-end test of per-branch dev deploy

**Why**: Validates the full `deploy-dev.yml` pipeline: OIDC auth → `az acr build` → KV secret read → container app create/update → hostname bind → wildcard cert attach → PR comment.

**How**:

```bash
git checkout -b feature/test-cicd
echo "// ci test $(date)" >> src/web/src/App.tsx
git add . && git commit -m "test: trigger dev deploy"
git push origin feature/test-cicd
```

Then:
1. Go to <https://github.com/renerios64/todo/actions> → watch **Deploy Dev (per-branch)** run
2. Open a PR from `feature/test-cicd` to `main` — the workflow will post a comment with URLs
3. Verify `https://feature-test-cicd.dev.todo.reneriosleon.com` loads the web UI
4. Verify `https://feature-test-cicd.dev.todo.reneriosleon.com/api/health` returns HTTP 200
5. Close the PR or delete the branch — watch **Teardown Dev** workflow run and verify the container apps are removed

**Troubleshooting**:
- `az acr build` fails → dev SP (`cdcf6cb4-07ea-4724-b0dd-69c2163da602`) missing AcrPush on `acrtododeva8ca4a`
- KV secret read fails → dev SP missing `Key Vault Secrets User` on `kv-todo-dev-a8ca4a`; the secret name is `db-connection-string`
- Hostname bind fails → wildcard cert resource ID in `deploy-dev.yml` env block may be stale; verify cert name `wildcard-dev-todo` exists in dev CAE: `az containerapp env certificate list -g rg-todo-dev-eastus2 -n cae-todo-dev -o table`
- Container app starts but crashes → `Database.Migrate()` failing; check container logs: `az containerapp logs show --name ca-api-dev-<slug> -g rg-todo-dev-eastus2 --follow`
- Slug computation: branch `feature/test-cicd` → slug `feature-test-cicd`; URL: `feature-test-cicd.dev.todo.reneriosleon.com`

---

### Step 7 — End-to-end test of prod deploy (after Steps 1–5 complete)

```bash
# From main branch
git checkout main
# Make a trivial change or just trigger manually
git commit --allow-empty -m "test: trigger prod deploy"
git push origin main
```

1. Watch **Deploy to Prod** workflow start
2. It will pause at the `production` environment gate — go to the workflow run in GitHub and click **Review deployments → Approve**
3. Verify `https://todo.reneriosleon.com` and `https://api.todo.reneriosleon.com/api/health` are live

---

### Phase 5 — Prod Blue/Green Rollout (not started)

**Goal**: Zero-downtime prod deploys using Azure Container Apps revision traffic splitting.

**How it works**: Container Apps supports multiple simultaneous revisions. Deploy the new image as a new revision with 0% traffic, run a smoke check against its direct URL, then shift traffic to 100% on success. If smoke check fails, deactivate the new revision — the old one never stopped serving traffic.

#### Implementation steps

**5a. Enable multiple-revision mode on prod container apps**

Run once after prod is recreated (Step 3):

```bash
az containerapp revision set-mode \
  --name ca-api-todo-prod \
  --resource-group rg-todo-prod-eastus2 \
  --mode multiple

az containerapp revision set-mode \
  --name ca-web-todo-prod \
  --resource-group rg-todo-prod-eastus2 \
  --mode multiple
```

**5b. Update `deploy-prod.yml` for blue/green**

Replace the current `az containerapp update` steps with this pattern:

```yaml
- name: Deploy new revision (green) at 0% traffic
  run: |
    TAG=${{ steps.tag.outputs.tag }}
    az containerapp update \
      --name ${{ env.API_APP }} \
      --resource-group ${{ env.RESOURCE_GROUP }} \
      --image ${{ env.ACR }}/todo-api:$TAG \
      --revision-suffix $TAG

    az containerapp update \
      --name ${{ env.WEB_APP }} \
      --resource-group ${{ env.RESOURCE_GROUP }} \
      --image ${{ env.ACR }}/todo-web:$TAG \
      --revision-suffix $TAG

- name: Smoke check new API revision
  run: |
    TAG=${{ steps.tag.outputs.tag }}
    CAE_DOMAIN=$(az containerapp env show \
      --name cae-todo-prod \
      --resource-group rg-todo-prod-eastus2 \
      --query properties.defaultDomain -o tsv)

    NEW_REVISION="${{ env.API_APP }}--$TAG"
    SMOKE_URL="https://${NEW_REVISION}.${CAE_DOMAIN}/api/health"

    for i in {1..10}; do
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$SMOKE_URL")
      if [ "$STATUS" = "200" ]; then
        echo "✅ Smoke check passed"
        exit 0
      fi
      echo "Attempt $i: got $STATUS, retrying in 10s..."
      sleep 10
    done
    echo "❌ Smoke check failed — rolling back"
    exit 1

- name: Shift traffic to new revision
  if: success()
  run: |
    TAG=${{ steps.tag.outputs.tag }}
    NEW_REVISION="${{ env.API_APP }}--$TAG"
    az containerapp ingress traffic set \
      --name ${{ env.API_APP }} \
      --resource-group ${{ env.RESOURCE_GROUP }} \
      --revision-weight "${NEW_REVISION}=100"

    NEW_REVISION="${{ env.WEB_APP }}--$TAG"
    az containerapp ingress traffic set \
      --name ${{ env.WEB_APP }} \
      --resource-group ${{ env.RESOURCE_GROUP }} \
      --revision-weight "${NEW_REVISION}=100"

- name: Deactivate old revisions
  if: success()
  run: |
    TAG=${{ steps.tag.outputs.tag }}
    for APP in ${{ env.API_APP }} ${{ env.WEB_APP }}; do
      OLD_REVISIONS=$(az containerapp revision list \
        --name $APP \
        --resource-group ${{ env.RESOURCE_GROUP }} \
        --query "[?name != '${APP}--${TAG}' && properties.active == true].name" -o tsv)
      for REV in $OLD_REVISIONS; do
        az containerapp revision deactivate \
          --revision $REV \
          --name $APP \
          --resource-group ${{ env.RESOURCE_GROUP }}
      done
    done
```

**5c. Add emergency rollback via `workflow_dispatch`**

Add a manual trigger to `deploy-prod.yml` that sets any named revision back to 100% traffic:

```yaml
on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      rollback_to_revision:
        description: 'Revision name to roll back to (e.g. ca-api-todo-prod--abc1234)'
        required: false
```

Then add a job step at the top:

```yaml
- name: Rollback (manual only)
  if: github.event_name == 'workflow_dispatch' && inputs.rollback_to_revision != ''
  run: |
    az containerapp ingress traffic set \
      --name ${{ env.API_APP }} \
      --resource-group ${{ env.RESOURCE_GROUP }} \
      --revision-weight "${{ inputs.rollback_to_revision }}=100"
    echo "⏪ Rolled back to ${{ inputs.rollback_to_revision }}"
```

