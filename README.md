# Physical GitOps Architecture

This repository contains the complete declarative configuration for my personal infrastructure, managed using GitOps principles with Argo CD. It follows a **Hub-and-Spoke** architecture, distributing workloads across public cloud and on-premise hardware based on performance and cost-efficiency.

## 🏗 The Fleet (Clusters)

Workloads are mapped to physical clusters rather than logical environments, allowing for fine-grained hardware utilization.

| Cluster | Role | Platform | Architecture | Hardware/Specs |
| :--- | :--- | :--- | :--- | :--- |
| **OCI** | **Cloud Hub** | Oracle Cloud (OKE) | `arm64` | 2 managed nodes (ARM), 12GB RAM |
| **Azure** | **Cloud Spoke** | Azure AKS | `amd64` | `aks-homelab`, Spot instances |
| **Home** | **On-Prem Compute** | K3s (Ubuntu 26.04) | `amd64` | Dedicated Mini-PC (CP) + 2x Laptops (Workers) |

### Workload Distribution
*   **OCI (The Cloud Hub):** Cloudflare Tunnels and public-facing lightweight apps like `paulojauregui-com`.
*   **Azure (Cloud Spoke):** Scalable cloud compute for managed services and secondary application hosting.
*   **Home (The Local Engine):** High-performance compute, Cilium eBPF, local autonomous ArgoCD, stateful databases (PostgreSQL/CNPG, MongoDB), and data engineering (Spark, MLflow).

## 📂 Repository Structure

The repository is organized by physical infrastructure boundaries to minimize drift and simplify multi-cloud management.

```plaintext
k8s-gitops/
├── clusters/               # Entry points for ArgoCD "App of Apps"
│   ├── home/               # Local K3s cluster configuration
│   ├── azure/              # Azure AKS cluster configuration
│   └── oci/                # OCI OKE cluster configuration
├── infrastructure/         # Platform-level services (Ingress, Cert-Manager, etc.)
│   ├── base/               # Common Helm values and manifests
│   └── overlays/           # Physical cluster-specific patches
│       ├── home/
│       ├── azure/
│       └── oci/
└── apps/                   # User-facing applications (MLflow, Blog, etc.)
    ├── base/               # Base deployment manifests
    └── overlays/           # Physical cluster-specific patches
        ├── home/
        ├── azure/
        └── oci/
```

## 🛠 Core Technology Stack

*   **ArgoCD (Local & Cloud Instances):** All Helm-based deployments use the Multiple Sources feature. Clean `values.yaml` files are stored in this repo, while charts are pulled directly from upstream. The on-prem K3s cluster runs an autonomous in-cluster ArgoCD instance for maximum local resilience.
*   **Secret Management (Doppler + ESO):** No secrets are stored in Git. External Secrets Operator (ESO) fetches encrypted secrets from a centralized **Doppler** vault (`k8s-eso` project).
*   **Networking:** **Cilium CNI** with full eBPF kube-proxy replacement on K3s; Cloudflare Tunnels for cloud ingress.
*   **Storage:** **OpenEBS LocalPV** and **SeaweedFS** manage dynamic local and distributed object storage.

## 🚀 GitOps Workflow

1.  **Configuration:** All changes are defined declaratively in `infrastructure/` or `apps/`.
2.  **App-of-Apps:** The root applications in `clusters/` track these directories.
3.  **Synchronization:**
    *   **OCI/Azure:** Automatically sync changes from Git.
    *   **Home (K3s):** Local in-cluster ArgoCD continuously reconciles from `main` targeting `https://kubernetes.default.svc`.
4.  **Security:** External Secrets are automatically injected into the target namespaces by ESO upon synchronization.

---
*For deep-dives into specific architectural decisions, see the [docs/architecture/](docs/architecture/) directory.*
