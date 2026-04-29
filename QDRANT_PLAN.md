# Qdrant Implementation Plan (Agentic Foundation)

This document outlines the step-by-step technical plan for deploying Qdrant (the Rust-based Vector Database) to the Talos Kubernetes cluster using a GitOps workflow (ArgoCD + Kustomize + Helm).

## Architecture & Constraints
*   **Deployment Method:** Kustomize integrating the official Qdrant Helm Chart.
*   **Namespace:** `qdrant` (Infrastructure layer).
*   **Storage:** Local storage via OpenEBS (`openebs-hostpath`) for maximum I/O performance (critical for vector indexes).
*   **Security:** API Key authentication enabled. The key will be stored in Doppler and injected into the cluster via the External Secrets Operator (ESO).
*   **Access:** Access to the REST API and the built-in Web UI (`:6333/dashboard`) will be managed via `kubectl port-forward` or an internal Ingress route (depending on the environment).

---

## Step 1: Secret Management (Doppler & ESO)

Before deploying the database, we must secure it. Qdrant requires an API key to restrict access to its REST and gRPC endpoints.

1.  **Generate API Key:** Generate a strong, random API key (e.g., using `openssl rand -hex 32`).
2.  **Store in Doppler:** Add this key to your Doppler project (`k8s-eso` or the specific environment config) under a variable name like `QDRANT_API_KEY`.
3.  **Create ExternalSecret Manifest:**
    *   Create `infrastructure/base/qdrant/01-external-secret.yaml`.
    *   Configure the `ExternalSecret` to fetch `QDRANT_API_KEY` from the Doppler `ClusterSecretStore` and create a Kubernetes Secret named `qdrant-api-key` in the `qdrant` namespace.
    *   The generated secret should have a key like `api-key` containing the value.

## Step 2: Base Kustomize & Helm Configuration

We will use Kustomize's Helm integration to template the Qdrant chart declaratively.

1.  **Create Namespace Manifest:**
    *   Create `infrastructure/base/qdrant/00-namespace.yaml` defining the `qdrant` namespace.
2.  **Create Qdrant Values File:**
    *   Create `infrastructure/base/qdrant/values.yaml`.
    *   **Configuration highlights:**
        *   `config.cluster.enabled: false` (Start with standalone mode for homelab, can scale later).
        *   `apiKey: true` (Enable authentication).
        *   Reference the generated Kubernetes Secret (`qdrant-api-key`) for the API key value via environment variables or chart values.
        *   `persistence.storageClassName: openebs-hostpath` (Ensure high performance).
        *   `persistence.size: 20Gi` (Adjust based on expected vector volume).
3.  **Create Kustomization File:**
    *   Create `infrastructure/base/qdrant/kustomization.yaml`.
    *   Include the namespace and secret manifests in `resources`.
    *   Use the `helmCharts` field to reference the Qdrant Helm repo (`https://qdrant.to/helm`), specify the chart version, and point to the `values.yaml` file.

## Step 3: Environment Overlay Configuration

Apply environment-specific tweaks for the Spoke cluster (Talos/home-dev).

1.  **Update Overlay Kustomization:**
    *   Navigate to `infrastructure/overlays/home-dev/`.
    *   Add `../../base/qdrant` to the `resources` list in `kustomization.yaml` (or create a dedicated `qdrant` overlay directory if structural patching is needed, e.g., `infrastructure/overlays/home-dev/qdrant`).
2.  *(Optional)* **Node Selectors/Tolerations:**
    *   If you want Qdrant to run on specific nodes (e.g., nodes with SSDs or specific ARM/AMD architecture), add a Kustomize patch to apply node selectors.

## Step 4: ArgoCD Application Registration

Register the new infrastructure component with the GitOps controller.

1.  **Update Root Application:**
    *   If `qdrant` is added directly to `infrastructure/overlays/home-dev/kustomization.yaml`, ArgoCD will automatically detect and deploy it when the `infra-root` application syncs.
    *   Alternatively, if you manage it as a distinct App-of-Apps child, create an `Application` manifest (e.g., `infrastructure/apps/qdrant.yaml`) pointing to the `home-dev/qdrant` path and add it to the root Kustomization.

## Step 5: Deployment & Validation

1.  **Git Commit & Push:** Commit the new manifests to the repository and push to the main branch.
2.  **ArgoCD Sync:** Monitor the ArgoCD UI or CLI to ensure the `qdrant` resources are synchronized and healthy.
3.  **Verify Pods & Storage:**
    *   `kubectl get pods -n qdrant` (Ensure the Qdrant pod is `Running`).
    *   `kubectl get pvc -n qdrant` (Ensure the PersistentVolumeClaim is `Bound` to OpenEBS).
4.  **Access the Built-in UI:**
    *   `kubectl port-forward svc/qdrant -n qdrant 6333:6333`
    *   Open a browser and navigate to `http://localhost:6333/dashboard`.
    *   When prompted, enter the `QDRANT_API_KEY` you generated in Step 1.
5.  **Test API via Python (Optional):**
    *   Write a quick Python script using the `qdrant-client` package to connect, authenticate, and create a test collection.