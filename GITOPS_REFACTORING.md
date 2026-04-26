# GitOps Architecture Refactoring Summary

This document summarizes the changes, architectural decisions, and improvements made during the Phase 4 GitOps Refactoring initiative.

## Overview
The primary goal of this refactoring was to improve maintainability, reduce boilerplate, and align the repository closer to modern GitOps and security best practices. The project transitioned from managing multiline Kustomize string patches and Bitnami Sealed Secrets to using strongly-typed Helm configurations via ArgoCD's Multiple Sources feature and Doppler for centralized secret management.

## Key Improvements

### 1. Refactored Helm Values Management (ArgoCD Multiple Sources)
**Problem:** Helm values were historically injected into ArgoCD `Application` manifests using multiline Kustomize patches. This approach was brittle, lacked YAML schema validation, and was prone to indentation errors.
**Solution:** Migrated all infrastructure and application definitions to use ArgoCD's **Multiple Sources** feature.
- Created standalone `values.yaml` files for all Helm-based deployments (e.g., `kube-prometheus-stack`, `ingress-nginx`, `cert-manager`, `nvidia-device-plugin`).
- Updated ArgoCD `Application` manifests to pull the Helm chart from the upstream repository while pulling the clean, strongly-typed `values.yaml` directly from this Git repository.
- Removed all associated Kustomize patches for Helm values.

### 2. Cleanup of Root Directory & Security Verification
**Problem:** The repository root contained various administrative scripts, sealed secret master keys, and bootstrap files (e.g., `argocd-cm.yaml`, `master-key-backup.yaml`), polluting the GitOps source of truth.
**Solution:** Secured the root directory structure.
- Created a dedicated `bootstrap/` directory for one-off administrative and cluster creation files.
- Removed sensitive and tracked bootstrap files from the Git cache (`git rm --cached`).
- Updated the `.gitignore` to explicitly ignore the `/bootstrap/` directory, temporary `/.secrets/` directories, and sensitive file types (`*.crt`, `*secret*.yaml`, `*backup*.yaml`).

### 3. Consolidated Duplicate App-of-Apps Definitions
**Problem:** Ambiguous and duplicated ArgoCD Application definitions existed within cluster overlays (e.g., conflicting `apps.yaml` and `apps-root.yaml` in `home-dev`).
**Solution:** Cleaned up orphaned resources and standardized cluster structures.
- Removed duplicate files in `home-dev` and orphaned `ApplicationSet` manifests in `oci-prod`.
- Standardized the `kustomization.yaml` structure across `home-dev`, `oci-prod`, and `staging` directories to ensure all environments compile successfully via `kustomize build`.

### 4. Standardized Secret Management (Migration to Doppler via ESO)
**Problem:** The repository relied heavily on Bitnami Sealed Secrets. Managing asymmetric encryption keys per cluster, backing up master keys, and encrypting individual secrets locally became a significant operational burden for a multi-cloud footprint.
**Solution:** Migrated entirely to a centralized SaaS vault (**Doppler**) integrated natively via the **External Secrets Operator (ESO)**.
- Removed the Bitnami Sealed Secrets controller from all infrastructure overlays.
- Deleted all `SealedSecret` manifests across the repository.
- Configured a `ClusterSecretStore` to authenticate with Doppler.
- Created declarative `ExternalSecret` manifests for all applications (`cert-manager`, `grafana`, `mlflow`) to fetch secrets directly from Doppler.

## Final Required Action
To finalize the Doppler integration, a Doppler Service Token must be bootstrapped into each Kubernetes cluster manually:

```bash
kubectl create secret generic doppler-token-secret \
  --namespace external-secrets \
  --from-literal=dopplerToken="<DOPPLER_SERVICE_TOKEN>"
```

Once applied, the `ClusterSecretStore` will immediately authenticate with Doppler and inject the configured secrets into the necessary namespaces.
