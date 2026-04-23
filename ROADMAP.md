# Roadmap: Observability Centralization and MLflow

## 1. Project Context Summary
- **Current State:** The Hub-and-Spoke GitOps model is fully operational. The OCI Cluster (Hub) is actively managing the Talos Cluster (Spoke) via a secure Cloudflare Zero Trust Tunnel. Talos infrastructure (HA Postgres, MongoDB, External Secrets via Doppler) has been stabilized and deployed successfully.
- **Goal:** Optimize resources on the Talos lab hardware by centralizing dashboards on the cloud Hub, and prepare the Talos cluster for AI/ML workloads by deploying MLflow.

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
> 2. Help me execute Phase 1: Centralized Observability. We need to configure the Talos Prometheus to send data to OCI, add it as a data source in the OCI Grafana, and disable the local Grafana UI on Talos to save resources."
