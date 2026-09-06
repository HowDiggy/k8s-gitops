# Self-Hosted Homelab Services

This directory provides operational runbooks, architecture references, and maintenance procedures for user-facing self-hosted services running on the local **K3s Homelab Cluster** (`home`).

---

## 1. Global Infrastructure Standards & Conventions

All services documented here adhere to strict cluster-wide conventions established in the GitOps repository.

### 1.1 Ingress & Routing (Cilium Gateway API)
- **Gateway Resource:** `homelab-gateway` located in the `argocd` namespace.
- **Gateway Class:** `cilium` utilizing Cilium eBPF L7 Envoy routing.
- **L2 Floating VIP:** `192.168.1.60` announced via Cilium L2 Announcement Policy across worker nodes.
- **Internal TLD:** `*.homelab.local` resolved via static DNS records on the UniFi Dream Machine Gateway.
- **Routing Protocol:** Every service exposes two `HTTPRoute` resources:
  1. Port `80` listener (`http`): Enforces an automatic `301 Moved Permanently` redirect to `https`.
  2. Port `443` listener (`https`): Terminates TLS (or passes through) and proxies traffic to the ClusterIP Service.

### 1.2 Storage Architecture & Concurrency Rules (OpenEBS LocalPV)
- **Storage Class:** `openebs-hostpath`.
- **Access Mode:** Strictly `ReadWriteOnce` (RWO) backed by node-local ext4/xfs filesystems.
- **Deployment Concurrency Directive (`strategy: type: Recreate`):**
  - Standard Kubernetes deployments default to `RollingUpdate`, which schedules replacement pods *before* terminating existing pods.
  - Because `openebs-hostpath` volumes are locked to the hosting node and cannot be mounted across multiple pods simultaneously, a `RollingUpdate` will deadlock the scheduler with `Multi-Attach error for volume`.
  - **Rule:** Every Deployment utilizing `openebs-hostpath` **must** declare:
    ```yaml
    spec:
      replicas: 1
      strategy:
        type: Recreate
    ```

### 1.3 Secret Management (Doppler + ESO)
- **Provider:** Doppler vault.
- **Project / Environment:** `k8s-eso` / `dev`.
- **Operator:** External Secrets Operator (ESO) syncing via `ClusterSecretStore/doppler-backend`.
- **Declarative Rule:** Zero plaintext credentials in Git. All secrets must be provisioned in Doppler, mapped via an `ExternalSecret` manifest, and generated dynamically in the workload namespace.

### 1.4 GitOps Directory Pattern (App of Apps)
Each application follows a strictly modular separation of concerns:
```
apps/
├── base/<service>/                # Environment-agnostic manifests (Namespace, Deployment, PVC, Service, HTTPRoute)
└── overlays/home/<service>/       # Cluster-specific patches and kustomization
```
The root application [`clusters/home/apps-root.yaml`](../../clusters/home/apps-root.yaml) monitors [`apps/overlays/home/kustomization.yaml`](../../apps/overlays/home/kustomization.yaml), which registers each service via an individual ArgoCD `Application` manifest.

---

## 2. Service Catalog

| Service | Subdomain | Primary Engine | Persistence Mechanism | Database Backend | Runbook |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Mealie** | `mealie.homelab.local` | FastAPI + Vue 3 SPA (`v3.25.1`) | OpenEBS LocalPV (`/app/data`, 10Gi) | PostgreSQL (CloudNativePG `Cluster`, 5Gi) | [mealie.md](mealie.md) |
| **Calibre-Web** | `calibre.homelab.local` | Python/Flask + S6 (`v0.6.27`) | OpenEBS LocalPV (`/config` 5Gi, `/books` 50Gi) | Dual SQLite (`app.db`, `metadata.db`) | [calibre-web.md](calibre-web.md) |

---

## 3. General Maintenance Protocol

Whenever updating configuration, changing storage classes, or bumping image tags:

1. **Verify Git Sync:** Ensure in-cluster ArgoCD is in a clean, synced state before making changes.
2. **Review PVC Sizing:** Storage volume expansions in Kubernetes can be applied online if the CSI driver supports expansion, but capacity cannot be decreased.
3. **Database Pre-flight:** Always take a manual backup or snapshot of the database layer prior to major application version bumps.
4. **Inspect S6 / Entrypoint Logs:** For containers utilizing process supervisors (like LinuxServer's S6-overlay), monitor initialization logs directly after pod restarts to verify permission drops and mod injections.
