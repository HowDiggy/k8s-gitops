# Azure AKS Migration and GitOps Refactoring Plan

## Overview
This document outlines the strategic pivot from OCI (Always Free) to Azure Kubernetes Service (AKS). The goal is to build an enterprise-grade, cost-optimized cluster using Spot Instances while gaining hands-on experience with Azure Key Vault, Workload Identity, and Azure DevOps pipelines, directly aligning with the engineer's career goals.

### Architecture & Constraints
- **Compute:** 3-node AKS cluster using `Standard_D2as_v5` Spot instances (2 vCPU, 8GB RAM per node).
- **Budget:** < $100 / month.
- **Secrets Management:** Migrate from Doppler to Azure Key Vault using External Secrets Operator (ESO) and Azure Workload Identity.
- **CI/CD:** Helm value management across tenants via Azure DevOps pipelines.

---

## 🟢 Milestone 1: The GitOps Archive Pattern (Preserving `home-dev`)
**Status:** Completed

- [x] 1. Archive local Talos cluster configurations out of ArgoCD's active sync scope.
- [x] 2. Create `RESTORE_CLUSTER.md` for future local deployment recovery.

---

## 🟢 Milestone 2: Prepping the Azure Environment (Infrastructure as Code)
**Status:** Completed

Provision the foundational Azure resources.

- [x] 1. Create Resource Group (`rg-homelab`).
- [x] 2. Provision Azure Key Vault and configure RBAC (`kv-homelab-secrets-...`).
- [x] 3. Provision AKS Cluster (Free Tier Control Plane).
      - Set up a system node pool (1 `Standard_D2as_v6` on-demand) to ensure core services survive Spot evictions.
      - Add a user node pool with **Spot Instances** (`Standard_D2as_v7/v6`, 3 nodes max).
- [x] 4. Enable OIDC Issuer and Workload Identity on the AKS cluster.

---

## 🟢 Milestone 3: Key Vault & Workload Identity Integration
**Status:** Completed

Establish secure, passwordless secret retrieval.

- [x] 1. Create a Managed Identity for the External Secrets Operator (ESO).
- [x] 2. Grant the Managed Identity `Key Vault Secrets User` role on the Key Vault.
- [x] 3. Establish Federated Identity Credential linking the AKS Service Account to the Azure Managed Identity.
- [x] 4. Deploy ESO and configure a `ClusterSecretStore` pointing to Azure Key Vault.

---

## 🟢 Milestone 4: Migrating GitOps Overlays to Azure (`azure-prod`)
**Status:** In Progress

Refactor the GitOps repository structure for the new environment.

- [x] 1. Create `infrastructure/overlays/azure-prod/` and `apps/overlays/azure-prod/`.
- [x] 2. Port base workloads (MongoDB, SeaweedFS, Qdrant) into the new overlay.
- [x] 3. Implement Pod Disruption Budgets (PDBs) and Node Selectors/Tolerations to ensure workloads are scheduled appropriately across the Spot node pool.
- [ ] 4. Migrate secrets from Doppler to Azure Key Vault.

---

## 🟡 Milestone 5: Azure DevOps Pipeline Integration
**Status:** Pending

Establish multi-tenant Helm value management via Azure DevOps.

- [ ] 1. Create an Azure DevOps Project.
- [ ] 2. Set up pipeline definitions (`azure-pipelines.yml`) to manage and validate Helm values for different environments/tenants before ArgoCD syncs them.
