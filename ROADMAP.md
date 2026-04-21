# Project Roadmap

This document outlines the planned future enhancements for this multi-cluster Kubernetes environment. The goal is to build upon the current foundation to implement more advanced, professional-grade DevOps and CI/CD practices.

## Phase 1: Automated Promotions Pipeline
The first major goal is to create a CI/CD pipeline that automates the deployment lifecycle of applications, using the blog (`paulojauregui-com`) as the initial use case and will at some point include my other project [SignConnect](https://github.com/HowDiggy/SignConnect).

* **Trigger**: The pipeline will be triggered by a push to any feature branch in the Git repository.
* **CI (Continuous Integration)**:
    * GitHub Actions automatically builds a new multi-arch container image.
    * Then pushes new image to a container registry (GHCR) with a unique tag.
* **CD (Continuous Deployment) to Development**:
    * The pipeline will automatically update a Kustomize patch in the `apps/overlays/development` directory to use the new image tag.
    * Argo CD will detect this change and deploy the new version to the `home-dev` cluster for testing.
* **Manual Promotion to Production**:
    * After verifying the changes in the development environment, a manual approval step (e.g., merging a pull request to `main`) will trigger the production deployment.
    * This will involve updating the image tag in the `apps/overlays/production` Kustomize overlay, which Argo CD will then sync to the `oci-prod` cluster.

---

## Phase 2: Staging Environment
To further de-risk production deployments, a third environment that serves as a final quality gate will be introduced.

* **Goal**: Create a "staging" environment that is an exact replica of the production cluster's configuration.
* **Implementation**:
    * Create a new directory: `clusters/oci-staging`.
    * Create a new Kustomize overlay: `apps/overlays/staging`.
    * This overlay will mirror the `production` overlay's settings (e.g., `replicas: 2`, `arm64` node selector) to ensure a high-fidelity testing environment.
* **Workflow**: The promotion pipeline from Phase 1 will be updated to include a staging step. A change will first be deployed to `development`, then promoted to `staging` for final validation before being approved for `production`.

---

## Phase 3: Infrastructure Overlays
The final step is to apply the same Kustomize overlay pattern we use for applications to our infrastructure components. This will make the management of tools like `cert-manager` fully declarative and environment-aware.

* **Goal**: Manage differences in infrastructure components between clusters using Kustomize, eliminating the need for separate manual installations or configurations.
* **Use Case: `cert-manager`**:
    * Create a `base` manifest for the `cert-manager` Helm chart application in `infrastructure/base/cert-manager`.
    * Create a `production` overlay in `infrastructure/overlays/production` that deploys the `letsencrypt-prod` `ClusterIssuer`.
    * Create a `development` overlay in `infrastructure/overlays/development` that deploys the `self-signed-issuer`.
* **Outcome**: This will allow Argo CD to manage the entire lifecycle of `cert-manager` and its configuration across both clusters from a single, DRY source, completing our GitOps setup.

---

## Phase 4: GitOps Architecture Refactoring
This phase focuses on improving maintainability, reducing boilerplate, and adhering closer to GitOps and security best practices.

* **Goal**: Clean up the repository structure, standardize secret management, and improve ArgoCD Application patterns.
* **Implementation**:
    * **Refactor Helm Values**: Migrate away from multiline inline string patches in Kustomize. Use ArgoCD "Multiple Sources" to reference standalone `values.yaml` files.
    * **Standardize Secret Management**: Transition completely from Sealed Secrets to External Secrets Operator (ESO) backed by a central vault (e.g., Doppler).
    * **Cleanup Root Directory**: Relocate administrative and one-off bootstrap scripts/manifests (and sensitive files) into a dedicated ignored `bootstrap/` directory to prevent cluttering the GitOps source of truth.
    * **Consolidate Definitions**: Remove duplicate or orphaned App-of-Apps manifests within cluster overlays.
* **Outcome**: A cleaner, more secure Git repository with strongly-typed Helm configurations and a solid foundation for migrating to a distributed architecture.

---

## Phase 5: Hybrid Cloud Architecture Migration
This phase shifts the infrastructure from a single cloud focus to a distributed, workload-specific hybrid cloud model utilizing both OCI and local hardware.

* **Goal**: Decommission heavy and legacy workloads from the resource-constrained OCI Edge cluster and deploy new, dedicated local clusters (Talos, DGX) to handle data engineering and ML.
* **Implementation**:
    * **Decommission SignConnect**: Remove the `signconnect` application and `cnpg-operator` databases from OCI production to free up Pod and CPU capacity.
    * **Establish Secure Connectivity**: Implement Tailscale or Cloudflare Tunnels to allow the OCI ArgoCD Control Plane to securely manage the private Home Lab clusters without opening local router ports.
    * **Provision Talos Lab**: Build and register the 3x Laptop Talos cluster (`clusters/talos-lab`) as the primary Data Engineering Hub (Airflow, PySpark).
    * **Provision AI Accelerators**: Build and register the DGX/P620 cluster (`clusters/dgx-ai`) dedicated to MLOps, Kubeflow, and model training.
* **Outcome**: A professional, multi-tier hybrid architecture capable of running heavy data and ML workloads locally for free, orchestrated by a highly available public cloud control plane.
