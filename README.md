# CoreBazaar

A GitHub-ready starter for an Indian B2B/B2C computer-components marketplace. It includes a small Node.js API, a PostgreSQL schema, local Docker Compose setup, Kubernetes manifests, and an AWS EKS Terraform example organized behind cloud-specific modules.

> **Starter, not a production marketplace.** Authentication, seller onboarding/KYC, product write APIs, checkout, inventory reservation, payment-provider calls, tax rules, fulfillment, and operational controls still need to be implemented and reviewed before handling real users or money. Never store card details or bank credentials.

## Repository map

```text
.
├── backend/                    # Stateless Node.js API
├── frontend/                   # Static catalog storefront served by Nginx
├── db/init/                    # PostgreSQL schema loaded on first local startup
├── docs/                       # Architecture and payment flow
├── infra/
│   ├── environments/dev/       # EKS example and backend config template
│   └── modules/
│       ├── aws-network/
│       └── aws-eks/
└── k8s/base/                   # Kubernetes Deployment, Service, Ingress, HPA
```

## Run locally

Requirements: Docker Engine with the Compose plugin. From the repository root:

```powershell
Copy-Item .env.example .env
# Edit .env and set a unique local POSTGRES_PASSWORD; set DATABASE_URL to the
# same password (URL-encode special characters in the URL).
docker compose up --build
```

Check `http://localhost:8080/health/live`, `http://localhost:8080/health/ready`, and `http://localhost:8080/api/products`. PostgreSQL schema initialization occurs only when the database volume is first created. To apply later schema changes, use a migration tool in a real deployment; do not rely on the one-time initialization mount.
The static storefront is available at `http://localhost:8081` and calls the API through the Nginx reverse proxy.

To stop: `docker compose down`. To also remove the local database volume, run `docker compose down --volumes` (this deletes local database data).

## Run API unit tests

Requirements: Node.js 20 or later. From the repository root:

```powershell
Set-Location backend
npm install
npm test
```

The tests exercise HTTP health/catalog routes with a stub database pool, invalid pagination handling, generic database errors, and port configuration parsing. They do not require a running PostgreSQL instance.

## Product direction

- **Buyers:** Browse component categories, compare listings, place multi-seller orders, pay, and track fulfillment.
- **Sellers:** Complete provider-supported onboarding/KYC, publish products, manage stock, process seller suborders, and reconcile settlements.
- **Marketplace:** Maintain a category tree, inventory reservations, order-item snapshots, provider payment references, a commission ledger, and auditable refunds.
- **Initial commission example:** 300 basis points (3%). Treat the commission base, GST, shipping, discounts, refunds, and rounding rules as explicit business/tax decisions, not assumptions hidden in code.

The detailed architecture, schema decisions, payment sequence, settlement caveats, and production checklist are in [`docs/architecture.md`](docs/architecture.md) and [`docs/payments.md`](docs/payments.md).

## Kubernetes

The manifests in [`k8s/base/`](k8s/base/) deploy the static storefront and stateless API. PostgreSQL/Redis are external service endpoints; provision them using an appropriate managed or separately operated data platform. Configure `DATABASE_URL` and PSP credentials through a secret manager and a cluster integration such as External Secrets; the example intentionally does not include credentials or an in-repository Secret manifest.

Before applying, replace the example images and hostnames, provide the referenced Secret, install a compatible Ingress controller and metrics server, and create a TLS secret whose certificate covers both example hosts. The Ingress class and controller are cluster-specific, so they are the main Kubernetes portability adaptation.

## Terraform

[`infra/environments/dev/`](infra/environments/dev/) is an AWS EKS example, not a universal managed-Kubernetes implementation. Terraform syntax and module interfaces are portable; EKS/GKE/AKS resources, IAM, networking, and remote-state backends are provider-specific. Implement equivalent provider modules while preserving a shared interface if swapping clouds is a requirement.

1. Create and secure the remote state bucket out of band (versioning, encryption, public access blocked, least-privilege access).
2. Copy `backend.hcl.example` to `backend.hcl` and replace the bucket/account-specific values. This file is ignored by Git.
3. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in the environment’s CIDRs, region, and allowlisted admin IP ranges.
4. From `infra/environments/dev/`, run `terraform init -backend-config=backend.hcl`, `terraform plan`, and review the plan before `terraform apply`.

State contains infrastructure metadata and must be protected. Do not commit state, real `.tfvars`, credentials, kubeconfig files, or provider secrets.

## GitHub repository

This project is published at [github.com/sohailk2608/CoreBazaar](https://github.com/sohailk2608/CoreBazaar). Clone it with:

```powershell
git clone https://github.com/sohailk2608/CoreBazaar.git
```

## License

No license has been selected. Choose one before inviting contributions or granting reuse rights.
