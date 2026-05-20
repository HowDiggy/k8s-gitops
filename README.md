# Physical GitOps Architecture

This repository contains the complete declarative configuration for my personal infrastructure, managed using GitOps principles with Argo CD. It follows a **Hub-and-Spoke** architecture, distributing workloads across public cloud and on-premise hardware based on performance and cost-efficiency.

## 🏗 The Fleet (Clusters)

Workloads are mapped to physical clusters rather than logical environments, allowing for fine-grained hardware utilization.

| Cluster | Role | Platform | Architecture | Hardware/Specs |
| :--- | :--- | :--- | :--- | :--- |
| **OCI** | **The Hub** | Oracle Cloud (OKE) | `arm64` | 2 managed nodes (ARM), 12GB RAM |
| **Azure** | **Cloud Spoke** | Azure AKS | `amd64` | `aks-homelab`, Spot instances |
| **Home** | **On-Prem Spoke** | Talos OS | `amd64` | 3x nodes (80GB RAM) + NVIDIA DGX Spark |

### Workload Distribution
*   **OCI (The Edge/Hub):** Host for "The Brain" (ArgoCD), Cloudflare Tunnels, and public-facing lightweight apps like `paulojauregui-com`.
*   **Azure (Cloud Spoke):** Scalable cloud compute for managed services and secondary application hosting.
*   **Home (The Engine):** High-performance compute, NVIDIA DGX Spark (GB10), stateful databases (PostgreSQL), and heavy data engineering (Spark, MLflow).

## 📂 Repository Structure

The repository is organized by physical infrastructure boundaries to minimize drift and simplify multi-cloud management.

```plaintext
k8s-gitops/
├── clusters/               # Entry points for ArgoCD "App of Apps"
│   ├── home/               # Local Talos cluster configuration
│   ├── azure/              # Azure AKS cluster configuration
│   └── oci/                # OCI OKE (Hub) cluster configuration
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

*   **ArgoCD (Multiple Sources):** All Helm-based deployments use the Multiple Sources feature. Clean `values.yaml` files are stored in this repo, while charts are pulled directly from upstream.
*   **Secret Management (Doppler + ESO):** No secrets are stored in Git. External Secrets Operator (ESO) fetches encrypted secrets from a centralized **Doppler** vault.
*   **Networking:** Outbound-only **Cloudflare Tunnels** connect the private `home` cluster to the internet and the OCI Hub without exposing local ports.
*   **Storage:** **OpenEBS** and **SeaweedFS** manage distributed storage across local nodes.

## 🚀 GitOps Workflow

1.  **Configuration:** All changes are defined declaratively in `infrastructure/` or `apps/`.
2.  **App-of-Apps:** The root applications in `clusters/` track these directories.
3.  **Synchronization:**
    *   **OCI/Azure:** Automatically sync changes from the `feat/azure-migration` (current) or `main` branches.
    *   **Home:** Syncs via the secure Cloudflare tunnel connection back to the Hub.
4.  **Security:** External Secrets are automatically injected into the target namespaces by ESO upon synchronization.

---
*For deep-dives into specific architectural decisions, see the [docs/architecture/](docs/architecture/) directory.*
