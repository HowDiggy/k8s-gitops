# Roadmap: Observability Centralization and MLflow

## 1. Project Context Summary
- **Current State:** The Hub-and-Spoke GitOps model is fully operational. The OCI Cluster (Hub) is actively managing the Talos Cluster (Spoke) via a secure Cloudflare Zero Trust Tunnel. Talos infrastructure (HA Postgres, MongoDB, External Secrets via Doppler) has been stabilized and deployed successfully.
- **Goal:** Optimize resources on the Talos lab hardware by centralizing dashboards on the cloud Hub, prepare the Talos cluster for AI/ML workloads by deploying MLflow, enhance ArgoCD security by disabling the default admin, and configure public ingress for centralized observability.

## 2. Implementation Roadmap

### Phase 1: Centralized Observability (Hub & Spoke Monitoring)
**Objective:** Make the OCI Grafana the primary dashboard ("Single Pane of Glass") by adding the Talos Prometheus instance as a remote data source, and scale down the redundant Grafana UI on Talos to save local resources.

1.  **Prometheus Remote Integration:**
    - Configure Prometheus on the Talos cluster to allow remote read queries, or configure a `remote_write` to send metrics up to the OCI Prometheus/Thanos instance over the secure tunnel.
2.  **OCI Grafana Configuration:**
    - Update the `kube-prometheus-stack` values on the OCI (`oci-prod`) overlay to provision a new data source pointing to the Talos Prometheus instance.
3.  **Talos Resource Optimization:**
    - Modify `infrastructure/overlays/home-dev/kps-values.yaml` to disable the Grafana UI component (`grafana.enabled: false`). The Talos cluster will now only act as a metric collector (Prometheus + Node Exporters).
4.  **GitOps Sync & Validation:** Apply changes via ArgoCD and verify that Talos metrics (e.g., node CPU/memory, GPU stats) are visible in the OCI Grafana dashboards.

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

### Phase 3: ArgoCD Security Hardening & Local User Management
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

### Phase 4: Observability Ingress Configuration
**Objective:** Configure public-facing, secure ingress routing for the OCI Hub's Grafana dashboard, allowing access via a custom subdomain (`grafana.paulojauregui.com`) similar to the existing ArgoCD setup (`argo.paulojauregui.com`).

1.  **DNS & TLS Configuration:**
    - Ensure DNS records (e.g., Cloudflare) are pointing `grafana.paulojauregui.com` to the correct load balancer / ingress controller.
    - Set up or verify a `ClusterIssuer` (cert-manager) is available to issue TLS certificates for the new domain.
2.  **Helm Values Update:**
    - Modify the `kube-prometheus-stack` values for the OCI Hub (`infrastructure/overlays/oci-prod/kps-values.yaml`).
    - Enable and configure the Ingress resource for Grafana, setting the `hosts` to `grafana.paulojauregui.com` and defining the necessary TLS block for cert-manager to provision the certificate automatically.
3.  **GitOps Sync & Validation:**
    - Sync the changes in ArgoCD.
    - Verify that navigating to `https://grafana.paulojauregui.com` routes correctly to the Grafana UI with a valid, trusted SSL certificate.

---

## 3. Handover Prompt for New Conversation

Copy and paste this prompt into a new Gemini CLI session to resume immediately:

> "I am continuing the Hybrid Cloud GitOps project. The Talos lab cluster is connected to OCI and stable with HA Postgres and MongoDB.
> 
> **Current State:**
> - OCI (Hub): `context-cxgwihujioa`
> - Talos (Spoke): `dalia` (VIP 192.168.1.50)
> - All base infrastructure (ESO, CNPG, MongoDB) is healthy.
> 
> **Instructions:**
> 1. Please read the `ROADMAP.md` in the root.
> 2. We have several phases to execute: Phase 1 (Centralized Observability), Phase 2 (MLflow Deployment), Phase 3 (ArgoCD Local User Setup), and Phase 4 (Grafana Ingress). Which one should we start with?"
