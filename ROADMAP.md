# Roadmap: MLflow and ArgoCD Security Hardening

## 1. Project Context Summary
- **Current State:** The Hub-and-Spoke GitOps model is optimized and stable. Centralized observability is operational: Talos metrics are queried directly from the OCI Hub's Grafana (`grafana.paulojauregui.com`), and the redundant local Grafana on Talos has been decommissioned. Cloud infrastructure costs have been reduced by consolidating all OCI services under a single load balancer (`192.9.242.180`).
- **Goal:** Prepare the Talos cluster for AI/ML workloads by deploying MLflow and enhance ArgoCD security by disabling the default admin and managing local users via Doppler.

## 2. Implementation Roadmap

### Phase 1: ArgoCD Security Hardening & Local User Management
**Objective:** Disable the built-in, default `admin` user in ArgoCD and provision a custom local user utilizing secure password hashes sourced from Doppler via External Secrets Operator.

1.  **Doppler Configuration:**
    - Generate a bcrypt hash for the new user's password using the ArgoCD CLI.
    - Store the bcrypt hash securely in the Doppler project.
2.  **Manifest Updates (ExternalSecret):**
    - Create an `ExternalSecret` in the `argocd` namespace utilizing the `Merge` creation policy to safely inject the password hash into the existing `argocd-secret` without overwriting system keys.
3.  **ConfigMap Updates (RBAC & Account Enablement):**
    - Modify the `argocd-cm` ConfigMap to enable the new user account for UI/CLI login and set `admin.enabled: "false"`.
    - Update the `argocd-rbac-cm` ConfigMap to grant `role:admin` privileges to the newly created user.
4.  **GitOps Sync & Validation:** Sync the ArgoCD application on the OCI Hub and verify that the default `admin` is locked out while the new custom user can authenticate successfully.

### Phase 2: MLflow Deployment
**Objective:** Deploy MLflow on the Talos home lab cluster to manage the machine learning lifecycle, track experiments, and store AI artifacts, leveraging the existing high-availability Postgres database.

1.  **Database & Storage Preparation:**
    - Create a dedicated database (`mlflow`) and user within the existing CloudNativePG (`signconnect-db`) cluster.
    - Set up an S3-compatible object store (like MinIO) on the Talos cluster for MLflow artifact storage, or configure an external bucket.
2.  **Secret Management:**
    - Generate MLflow database and artifact storage credentials and store them securely in Doppler.
    - Create an `ExternalSecret` manifest to synchronize these credentials to the namespace where MLflow will reside.
3.  **Manifest Creation:**
    - Create base manifests for the MLflow deployment and service in `apps/base/mlflow`.
    - Configure an overlay for `home-dev` (`apps/overlays/development/mlflow`) to deploy the application with proper resource limits.
4.  **GitOps Sync & Validation:** Deploy via ArgoCD, ensure the pods start successfully, and verify access to the MLflow tracking UI.

---

## 3. Handover Prompt for New Conversation

Copy and paste this prompt into a new Gemini CLI session to resume immediately:

> "I am continuing the Hybrid Cloud GitOps project. The Talos lab cluster is connected to OCI and stable with HA Postgres and MongoDB. Centralized observability is operational at `grafana.paulojauregui.com`.
> 
> **Current State:**
> - OCI (Hub): `context-cxgwihujioa`
> - Talos (Spoke): `dalia` (VIP 192.168.1.50)
> - Redundant OCI Load Balancer eliminated; all traffic consolidated on `192.9.242.180`.
> 
> **Instructions:**
> 1. Please read the `ROADMAP.md` in the root.
> 2. We have two main phases remaining: Phase 1 (ArgoCD Security Hardening) and Phase 2 (MLflow Deployment). Which one should we start with?"
