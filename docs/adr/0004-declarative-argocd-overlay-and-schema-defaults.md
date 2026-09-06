# 0004. Declarative ArgoCD Configuration Overlays, Doppler ESO Sync, and Schema Defaulting

* **Status:** Accepted  
* **Date:** 2026-09-05  
* **Scope:** GitOps Operations & Security  
* **Authors:** Paulo Jauregui  

---

## Context and Problem Statement

During the Gateway API implementation and operational audit, several configuration drift and synchronization issues were identified:
1. **Imperative Drift**: Critical ArgoCD parameters (`server.insecure: "true"` for Gateway API TLS offload and `url: "https://argocd.homelab.local"`) were applied imperatively via `kubectl patch`. They were not committed to Git and would be destroyed upon cluster redeployment.
2. **Security Hygiene**: The default `admin` account remained active in the cluster. Although credentials for the intended identity (`jaupau`) existed in Doppler (`k8s-eso / dev`), the `ExternalSecret` and RBAC ConfigMaps were not deployed to the Home overlay.
3. **Kustomize Helm Inflation Failure**: `spark-operator` failed to synchronize, throwing a `ComparisonError` with `must specify --enable-helm`.
4. **Persistent Schema Diff (`OutOfSync`)**: `home-cluster-issuers` reported perpetual `OutOfSync` because Kubernetes API admission defaulted fields on `ExternalSecret/cloudflare-api-token` were omitted from Git.
5. **Legacy Artifacts**: Obsolete manifests from the previous Talos cluster (`talos-cluster-eso.yaml`) remained unmanaged in `infrastructure/base/argocd/`.

---

## First-Principles Mental Model & Analysis

### 1. Transport-Layer Decoupling in Multi-Cluster GitOps
In a multi-cluster repository managing both public cloud (OCI) and on-premise (Home K3s) clusters, transport settings diverge:
- **OCI**: Public internet edge using Ingress-NGINX with Let's Encrypt TLS certificates.
- **Home K3s**: Local LAN edge using Cilium Gateway API (Envoy) terminating self-signed TLS at the LoadBalancer VIP. Behind the Gateway, `argocd-server` must run plaintext HTTP (`server.insecure: "true"`) to avoid double-TLS encryption.

Conflating transport configurations in `infrastructure/base/argocd/` breaks cross-environment portability. Transport settings must reside in cluster-specific overlays.

### 2. Kubernetes API Server Defaulting vs. GitOps Diff
ArgoCD compares desired state (Git) against live state (etcd). During resource creation, Kubernetes mutating admission webhooks populate default values:
- `ExternalSecret`: populates `target.creationPolicy: Owner`, `target.deletionPolicy: Retain`, `data[].remoteRef.conversionStrategy: Default`, `decodingStrategy: None`, `metadataPolicy: None`.
- `Gateway` / `HTTPRoute`: populates `group: ""`, `kind: Service`, `weight: 1`.

If Git manifests omit these defaulted fields, ArgoCD's diff engine treats the omitted keys as an ongoing divergence, locking applications into `OutOfSync`.

```
[ Git Manifest (Omitted Keys) ]        [ Kubernetes Live Object (Defaulted Keys) ]
  spec:                                   spec:
    target:                                 target:
      name: my-secret                         name: my-secret
                                              creationPolicy: Owner    <-- Diff flagged!
                                              deletionPolicy: Retain   <-- Diff flagged!
```

---

## Decision

1. **Create Dedicated Home ArgoCD Configuration Overlay**:
   Establish [`infrastructure/overlays/home/argocd-config/`](file:///Users/paulojauregui/projects/k8s-gitops/infrastructure/overlays/home/argocd-config):
   - `argocd-cmd-params-cm.yaml`: Declares `server.insecure: "true"`.
   - `argocd-cm.yaml`: Declares `url: "https://argocd.homelab.local"`, event exclusions, and `kustomize.buildOptions: "--enable-helm"`.
   - `argocd-rbac-cm.yaml`: Declares `g, jaupau, role:admin`.
   - `security.yaml`: `ExternalSecret` pulling `ARGOCD_ADMIN_USER` and `ARGOCD_ADMIN_PASSWORD_HASH` from Doppler (`ClusterSecretStore/doppler-backend`) into `argocd-secret`.
2. **Deploy as an ArgoCD Application**:
   Create [`infrastructure/overlays/home/argocd-config-app.yaml`](file:///Users/paulojauregui/projects/k8s-gitops/infrastructure/overlays/home/argocd-config-app.yaml) managed by the root `home-infra-root` app.
3. **Disable Default Admin Account**:
   Set `admin.enabled: "false"` and `accounts.jaupau: login` in `argocd-cm.yaml`. All administrative access transitions to `jaupau` via Doppler credentials.
4. **Explicitly Declare Schema Defaults**:
   Update [`external-cloudflare-token.yaml`](file:///Users/paulojauregui/projects/k8s-gitops/infrastructure/base/cert-manager-issuers/external-cloudflare-token.yaml) and `security.yaml` to include all API server defaulted keys.
5. **Prune Legacy Artifacts**:
   Delete `talos-cluster-eso.yaml` and add clarifying scope comments to `base/argocd/ingress.yaml`.

---

## Consequences

### Positive
- **Zero Imperative Drift**: All ArgoCD configurations are 100% version-controlled in GitOps.
- **Improved Security Posture**: Default `admin` user is disabled; passwords are automatically synchronized and rotated from Doppler.
- **Unblocked Manifest Generation**: Adding `kustomize.buildOptions: "--enable-helm"` resolved the `ComparisonError` in `spark-operator`, bringing it to `Synced` & `Healthy`.
- **100% Cluster Health**: All 18 applications in the fleet achieved `Synced` & `Healthy` state.

### Negative / Operational Caveats
- **Secret Store Dependency**: If the Doppler `ClusterSecretStore` fails, updates to ArgoCD credentials will stall (existing credentials in `argocd-secret` remain cached and functional).
