# Hybrid Cloud Architecture

This document outlines the strategic hardware and workload distribution for our multi-cluster Kubernetes environment. By leveraging a hybrid cloud model, we maximize the strengths of our free-tier public cloud resources alongside our powerful on-premise hardware.

## 1. OCI Cluster (The Edge & Control Plane)

**Environment:** Oracle Cloud Infrastructure (Always-Free Tier)
**Hardware:** 2x ARM Nodes (2 vCPU, 12GB RAM total)
**Role:** Public Ingress, Central Control Plane, and Lightweight Edge Apps.

### Core Responsibilities
Because this cluster has a permanent public IP and is always on, it acts as the gateway to the internet and the central management hub for all clusters.
* **ArgoCD (Cloud & Local):** GitOps controllers manage their respective clusters from this unified repository. OCI manages its edge services, while the Home K3s cluster runs an autonomous in-cluster ArgoCD for local resilience and zero WAN dependency.
* **Ingress & TLS:** `ingress-nginx`, `cert-manager`, and Cloudflare Tunnels handle all inbound internet traffic and SSL termination.
* **Edge Applications:** Lightweight, highly available applications like the personal blog (`paulojauregui-com`).
* **Secret Management:** Doppler + External Secrets Operator (ESO).

### Excluded Workloads
* No heavy stateful databases (e.g., PostgreSQL, Redis).
* No data engineering, ML, or heavy data processing tools (e.g., Spark, Airflow, MLflow).
* Keep total pod count per node strictly below the 31-pod OCI limit.

---

## 2. K3s Home Lab (The "Compute Engine")

**Environment:** Local On-Premise (Ubuntu Server 26.04 LTS)
**Hardware Architecture:**
* **Control Plane (`tiny` - 192.168.1.57):** Fanless 2-core mini-PC running agentless K3s server with embedded SQLite. Zero application workloads run on this node.
* **Worker 1 (`dito` - 192.168.1.58):** High-performance laptop worker node.
* **Worker 2 (`beet` - 192.168.1.59):** High-performance laptop worker node.

**Networking & Ingress:**
* **Cilium 1.20+ with eBPF:** Replaces `kube-proxy` entirely. High-performance service routing via eBPF maps and VXLAN overlay (`8472/udp`).
* **Kubernetes Gateway API & L2 Announcements:** Replaces legacy Ingress with Gateway API (`gateway.networking.k8s.io`). Cilium embedded Envoy handles TLS termination and L7 routing, with L2 ARP announcements broadcasting the floating LoadBalancer VIP (`192.168.1.60`) across worker nodes.
* **Observability:** Built-in Hubble relay and Hubble UI.

**Storage & Secret Management:**
* **OpenEBS Dynamic LocalPV:** Dynamic hostpath provisioning for all stateful workloads.
* **External Secrets Operator (ESO):** Reconciles application secrets directly from Doppler (`k8s-eso / dev`).

### Core Responsibilities
This cluster provides massive, cost-free x86 compute and fast local NVMe storage. With zero ingress/egress costs, it is the primary engine for heavy lifting.
* **Autonomous GitOps:** Runs its own in-cluster ArgoCD instance managing the `clusters/home` App-of-Apps tree.
* **Data Engineering Stack:** Multi-node Apache Spark clusters and MLflow tracking server.
* **Stateful Databases:** PostgreSQL (CloudNativePG), MongoDB 3-node replica sets, and Qdrant vector database.
* **Heavy Monitoring:** Complete `kube-prometheus-stack` with Prometheus HA, Alertmanager, and Node Exporters across workers.

---

## 3. The Accelerators (The "AI/HPC" Nodes)

**Environment:** Local On-Premise 
**Hardware:** Lenovo P620 (128GB RAM), NVIDIA DGX Spark (GB10/CUDA, 128GB Memory)
**Role:** Machine Learning, Model Training, and Inference.

### Core Responsibilities
These specialized machines are dedicated purely to compute-intensive, GPU-accelerated tasks. They can be orchestrated as a standalone cluster or integrated as dedicated nodes into the Talos cluster using strict node taints and tolerations.
* **MLOps:** Kubeflow or MLflow for model tracking and lifecycle management.
* **Training Jobs:** Spark or PyTorch training jobs scheduled by Airflow and constrained to these nodes.
* **Model Serving:** Hosting and serving custom models or LLMs.

## Detailed Architectural Decisions
For in-depth explanations of specific architectural implementations and troubleshooting resolutions, refer to our Architecture Documentation:
*   [Hub-and-Spoke GitOps Architecture (App of Apps)](docs/architecture/01-hub-and-spoke-gitops.md)
*   [Spark Operator Webhook & Cert-Manager Integration](docs/architecture/02-cert-manager-spark-operator.md)
*   [Multi-Architecture Node Affinity](docs/architecture/03-multi-arch-node-affinity.md)
*   [Architecture Decision Records (ADRs)](docs/adr/README.md)

---

## Future Networking Strategy

To allow the public OCI ArgoCD instance to securely manage the private Home Lab clusters without exposing local router ports, a secure mesh network or tunnel will be implemented:
* **Tailscale/WireGuard Subnet Router:** To join the OCI cluster and local clusters into a single flat private network.
* **Cloudflare Tunnels:** For secure, outbound-only connectivity from the local clusters to the public internet.
