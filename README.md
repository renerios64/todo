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

