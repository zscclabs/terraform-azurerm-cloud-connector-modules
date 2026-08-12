# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Terraform modules and example root configurations for deploying Zscaler Cloud Connector in Microsoft Azure. There is no application code — everything is HCL, plus a bash wrapper (`examples/zsec`) and a couple of support Python/bash scripts.

## Repository layout

- `modules/terraform-zscc-*-azure/` — reusable child modules (network, ccvm, ccvmss, lb, nsg, identity, bastion, workload, private-dns, function-app, ztags, and GWLB/public-lb variants referenced in CHANGELOG). Each module is self-contained: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `README.md`.
- `examples/` — root modules that wire child modules together via relative sources (`../../modules/terraform-zscc-*-azure`). Three deployment families, selected interactively by the `zsec` script:
  - **Greenfield** (`base`, `base_1cc`, `base_1cc_zpa`, `base_cc_lb*`, `base_cc_vmss*`, `base_cc_gwlb*`, `base_cc_public_lb*`) — builds a full sandbox: new resource group/VNet, bastion host, test workload VMs, and (depending on type) Cloud Connector VMs or VMSS.
  - **Brownfield** (`cc_lb`, `cc_vmss`, `cc_gwlb`, `cc_gwlb_vmss`) — production-oriented, more BYO customization (existing RG/VNet/subnets/PIPs/NAT GWs), no bastion/workload hosts.
  - **Standalone** (`ztags_standalone`) — provisions only the Zscaler Tag Discovery Service Event Grid plumbing; assumes Cloud Connector resources already exist.
- `examples/zsec` — bash wrapper that downloads a pinned Terraform binary, prompts for deployment family/type and Azure credentials, persists answers in a local `.zsecrc`, and drives `terraform init/apply/destroy`. This is the documented way end users (and you, when testing example changes) exercise the examples — plain `terraform apply` also works if variables are supplied directly.
- `scripts/manual_sync.sh` — jq-based script used by the VMSS Function App to reconcile Cloud Connector registration state.
- `scripts/support_bundle/` — standalone Python tool for collecting diagnostic bundles (own `requirements.txt`, unrelated to Terraform).
- `CHANGELOG.md` — versioned FEATURES/ENHANCEMENTS/BUG FIXES/NOTES log; update it for user-facing module/example changes.

## Common commands

Format and validate (mirrors `.github/workflows/ci.yml`, which runs per-module, not repo-wide `init`):

```bash
terraform fmt -check -recursive
cd modules/<module-dir> && terraform init && terraform validate -no-color
```

Regenerate a module's variable/output tables after changing `variables.tf`/`outputs.tf` (README content between the `<!-- BEGINNING/END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->` markers is generated, not hand-written):

```bash
terraform-docs --lockfile=false markdown table modules/<module-dir>
```

Run the full pre-commit suite (terraform_fmt, terraform_validate, terraform_docs, scoped tflint rules, gitlint, detect-secrets) exactly as configured in `.pre-commit-config.yaml`:

```bash
pre-commit run --all-files
```

Deploy/destroy an example end-to-end (interactive; requires real Azure credentials and a provisioned Key Vault/Managed Identity per the root README prerequisites):

```bash
cd examples && ./zsec up       # prompts for greenfield/brownfield/standalone, then deployment type
cd examples && ./zsec destroy
```
`AUTO_APPROVE=1` skips the apply/destroy confirmation prompt; `dtype=<type>` pre-selects the deployment type non-interactively.

## Conventions to preserve across modules/examples

- Every root example generates `random_string.suffix` and passes it as `resource_tag` into every child module, combined with `name_prefix`, to keep resource names unique and correlated across a deployment.
- A `global_tags` map (`Owner`, `ManagedBy = "terraform"`, `Vendor = "Zscaler"`, `Environment`) is built once in the root module and threaded through every child module call — new child modules should accept and apply `global_tags` the same way.
- Boolean feature toggles follow an `_enabled` suffix (`zones_enabled`, `zpa_enabled`, `accelerated_networking_enabled`, `encryption_at_host_enabled`, `lb_association_enabled`, etc.) — match this when adding new variables (see CHANGELOG note about renaming `has_private_lb`/`has_public_lb` to `private_lb_enabled`/`public_lb_enabled` for this reason).
- Cross-subscription managed identity lookups use an aliased provider block (`providers = { azurerm = azurerm.managed_identity_sub }`) declared in the root example's `versions.tf` — follow this pattern rather than adding a second default provider.
- Each module's `versions.tf` pins `required_providers` (azurerm, and as needed local/null/tls) and `required_version = ">= 0.13.7, < 2.0.0"`; keep provider version ranges consistent across modules when bumping (root README states the currently supported azurerm/random/local/null/tls versions).
- VMSS-based deployments always pair `terraform-zscc-ccvmss-azure` with `terraform-zscc-function-app-azure` (autoscaling/health-driven instance sync) and `scripts/manual_sync.sh`; VM-based (non-scale-set) deployments do not need the function app.
- GWLB/public-LB topologies (`terraform-zscc-gwlb-azure`, `terraform-zscc-public-lb-azure`) chain in front of the existing internal LB (`terraform-zscc-lb-azure`) for transparent inline inspection — these are additive to, not a replacement for, the standard private-LB egress topology.
