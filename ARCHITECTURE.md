# Hybrid Cloud Architecture

This document outlines the strategic hardware and workload distribution for our multi-cluster Kubernetes environment. By leveraging a hybrid cloud model, we maximize the strengths of our free-tier public cloud resources alongside our powerful on-premise hardware.

## 1. OCI Cluster (The Edge & Control Plane)

**Environment:** Oracle Cloud Infrastructure (Always-Free Tier)
**Hardware:** 2x ARM Nodes (2 vCPU, 12GB RAM total)
**Role:** Public Ingress, Central Control Plane, and Lightweight Edge Apps.

### Core Responsibilities
Because this cluster has a permanent public IP and is always on, it acts as the gateway to the internet and the central management hub for all clusters.
* **ArgoCD (The Brain):** The master GitOps controller. It monitors the GitHub repository and securely pushes configurations to *all* clusters (OCI, Talos, DGX) via secure tunnels (e.g., Tailscale, Cloudflare Tunnels).
* **Ingress & TLS:** `ingress-nginx`, `cert-manager`, and Cloudflare Tunnels handle all inbound internet traffic and SSL termination.
* **Edge Applications:** Lightweight, highly available applications like the personal blog (`paulojauregui-com`).
* **Secret Management:** Doppler + External Secrets Operator (ESO).

### Excluded Workloads
* No heavy stateful databases (e.g., PostgreSQL, Redis).
* No data engineering, ML, or heavy data processing tools (e.g., Spark, Airflow, MLflow).
* Keep total pod count per node strictly below the 31-pod OCI limit.

---

## 2. Talos Home Lab (The "Data Center")

**Environment:** Local On-Premise (Talos OS)
**Hardware:** 3x Laptops (12 Cores, 80GB RAM total)
**Role:** Heavy Compute, Data Engineering, Databases, and CI/CD.

### Core Responsibilities
This cluster provides massive, cost-free x86 compute and fast local NVMe storage. With zero ingress/egress costs, it is the primary engine for heavy lifting.
* **Data Engineering Stack:** Apache Airflow for orchestration and multi-node PySpark clusters.
* **Stateful Services:** PostgreSQL (CNPG), Redis, and object storage (e.g., MinIO).
* **CI/CD Runners:** Self-hosted GitHub Actions or GitLab Runners. Building multi-arch Docker images is computationally heavy and belongs here.
* **Heavy Monitoring:** The full `kube-prometheus-stack` with long-term retention and potentially Thanos to aggregate metrics from the Edge and AI clusters.

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

---

## Future Networking Strategy

To allow the public OCI ArgoCD instance to securely manage the private Home Lab clusters without exposing local router ports, a secure mesh network or tunnel will be implemented:
* **Tailscale/WireGuard Subnet Router:** To join the OCI cluster and local clusters into a single flat private network.
* **Cloudflare Tunnels:** For secure, outbound-only connectivity from the local clusters to the public internet.
