# Roadmap: GitOps, MLflow, and the AI-Enriched Lakehouse

## 1. Project Context Summary
- **Current State:** The Hub-and-Spoke GitOps model is optimized and stable. Centralized observability is operational: Talos metrics are queried directly from the OCI Hub's Grafana (`grafana.paulojauregui.com`). Cloud infrastructure costs have been reduced by consolidating all OCI services under a single load balancer (`192.9.242.180`). ArgoCD security has been hardened to disable the default admin and manage local users via Doppler.
- **Goal:** Transform the Talos cluster into an Enterprise-grade AI & Data Engineering platform. This involves deploying MLflow for model management and constructing an "AI-Enriched Lakehouse" pipeline mimicking a modern Databricks architecture, starting with PySpark batch processing and evolving into real-time streaming.

## 2. Implementation Roadmap

### [DONE] Phase 1: ArgoCD Security Hardening & Local User Management
- Generated a bcrypt hash for the new user's password using the ArgoCD CLI.
- Stored the bcrypt hash securely in the Doppler project.
- Created an `ExternalSecret` in the `argocd` namespace utilizing the `Merge` creation policy to safely inject the password hash into the existing `argocd-secret` without overwriting system keys.
- Modified the `argocd-cm` ConfigMap to enable the new user account (`jaupau`) for UI/CLI login and set `admin.enabled: "false"`.
- Updated the `argocd-rbac-cm` ConfigMap to grant `role:admin` privileges to the newly created user.

### [DONE] Phase 1.5: SignConnect Decommissioning
- Unregistered the `signconnect` application from all ArgoCD environment registries (development, staging, production).
- Deleted all `signconnect` Kustomize manifests from the `apps/base` and `apps/overlays` directories.
- Cleaned up local secrets and documentation references across the project.
- Pruned the `signconnect` namespace from all active clusters.

### [DONE] Phase 2: Open-Source Object Storage & MLflow Deployment
**Objective:** Deploy SeaweedFS (a lightweight, highly performant MinIO alternative) to serve as the S3-compatible Data Lake foundation, followed by MLflow for AI experiment tracking.

1.  **Deploy SeaweedFS (Data Lake Foundation):**
    - Deploy SeaweedFS via its official Helm Chart using Kustomize.
    - Configure it with S3 API endpoints and create the necessary buckets (`mlflow-artifacts`, `bronze-logs`, `silver-enriched`).
2.  **Database & Secret Preparation:**
    - Create a dedicated database (`mlflow`) within the existing HA Postgres cluster.
    - Generate SeaweedFS and Postgres credentials and store them securely in Doppler.
3.  **MLflow Manifest Creation & Sync:**
    - Create base manifests for the MLflow deployment pointing artifact storage to SeaweedFS.
    - Deploy via ArgoCD and verify the tracking UI.

### [DONE] Phase 2.5: The Agentic Foundation (Vector Database)
**Objective:** Deploy a centralized, always-on vector database to serve as the "Enterprise Memory" for your upcoming LLM agents.

1.  **Deploy Qdrant:**
    - Deploy the official Qdrant Kubernetes Operator (or Helm Chart) via Kustomize.
    - *Why Qdrant:* Written in Rust, it provides memory-safe, ultra-fast vector similarity search with a minimal footprint, making it ideal for the Talos edge cluster.
2.  **Provision and Secure:**
    - Provision a Qdrant cluster backed by local storage.
    - Generate API keys, store them in Doppler, and sync them to the cluster via the External Secrets Operator.

### [DONE] Phase 2.8: Network Engineering Lab (KubeVirt)
**Objective:** Build a self-contained, GitOps-managed virtual network sandbox to practice advanced routing, firewalling, and VPN concepts directly on the Talos hardware without impacting cluster stability.

1.  **Infrastructure:** Deployed Multus CNI for virtual layer-2 bridges and KubeVirt Operator for native VM orchestration.
2.  **Two-Site Topology:** Provisioned two Ubuntu 24.04 router VMs and two Ubuntu client VMs acting as a simulated multi-site corporate network traversing the Kubernetes pod network.
3.  **Documentation:** Detailed the [KubeVirt Networking Lab Architecture](docs/architecture/04-kubevirt-networking-lab.md) for future operational reference and LLM context.

### Phase 3: The Spark Foundation (Batch AI Lakehouse)
**Objective:** Deploy Apache Spark to mimic the core Databricks batch capabilities and prove out the AI UDF logic before introducing streaming complexity.

1.  **[DONE] Deploy the Kubernetes Operator:**
    - Deploy the official Spark Kubernetes Operator.
2.  **Prototype the PySpark Batch Job:**
    - Develop a PySpark script that reads a static Parquet file from SeaweedFS, applies a Vectorized Pandas UDF (calling the local DGX vLLM via `asyncio`), and writes the enriched dataset back as a Delta Table.

### Phase 4: The Streaming Backbone (Redpanda)
**Objective:** Deploy the infrastructure required to handle high-throughput, real-time data streams.

1.  **Deploy Redpanda:**
    - Deploy the Redpanda Operator (a lightweight, JVM-free Kafka alternative) and provision a cluster.
2.  **Data Generator (Producer):**
    - Write a lightweight Python script to generate synthetic "system path" logs and continuously publish them to a Redpanda topic (`raw-system-paths`).

### Phase 5: Structured Streaming Upgrade
**Objective:** Upgrade the PySpark pipeline from batch to Spark Structured Streaming to process the Redpanda data in real-time.

1.  **Refactor the PySpark Job:**
    - Modify the source from `spark.read` to `spark.readStream` subscribing to the Redpanda topic.
2.  **Sink to Delta Lake:**
    - Configure the streaming job to append the AI-enriched data continuously to the SeaweedFS Delta Table.

### Phase 6: Flink Mastery (Future/Optional)
**Objective:** Once the Spark Structured Streaming pipeline is flawless, deploy Apache Flink to contrast micro-batching with true event-driven streaming.

---

## 3. Handover Prompt for New Conversation

Copy and paste this prompt into a new Gemini CLI session to resume immediately:

> "I am returning to the k8s-gitops project. We recently executed a strategic pivot away from OCI/Talos to an Azure AKS environment leveraging Spot Instances and Azure Key Vault for enterprise-grade GitOps experience. 
> 
> Please read the `NEXT_SESSION_PLAN.md` file in the root of the repository to understand the exact state of the cluster and the immediate next steps regarding the Spot Node Pool provisioning and Milestone 5 (Azure DevOps integration)."