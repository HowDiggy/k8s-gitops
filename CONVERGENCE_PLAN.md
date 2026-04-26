# GitOps Pattern Standardization Plan: Explicit Kustomize for Applications

## 1. Objective
Converge the "Applications" layer of the GitOps repository onto the **Explicit Kustomize Pattern**. This eliminates directory-based "magic" discovery and ensures every application is explicitly registered in a Kustomize resource tree, matching the established pattern used in the "Infrastructure" layer.

## 2. Current State vs. Target State
*   **Current State:** Applications are managed via a mix of manual `kubectl apply` commands and directory-based discovery. Root applications (like `dev-app-paulojauregui-com`) point to folders without a `kustomization.yaml`, relying on ArgoCD's default behavior, and target workload namespaces (like `paulojauregui-com`) on the spoke cluster.
*   **Target State:** Every cluster has an "Apps Root" application that points to a specific overlay directory. That overlay directory contains a `kustomization.yaml` that explicitly lists every child application manifest (`Application` kind) to be deployed. Crucially, these child `Application` manifests must be deployed to the `argocd` namespace on the Hub cluster (`https://kubernetes.default.svc`), allowing ArgoCD to reconcile them.

---

## 3. Step-by-Step Implementation

### Step 1: Standardize the Development Apps Overlay
1.  **Create Registry:** Create `apps/overlays/development/kustomization.yaml`.
2.  **Relocate Manifests:** Move application registration manifests from `clusters/home-dev/` into the overlay:
    *   `clusters/home-dev/app-mlflow.yaml` -> `apps/overlays/development/mlflow-app.yaml`
    *   `clusters/home-dev/app-signconnect-dev.yaml` -> `apps/overlays/development/signconnect-app.yaml`
3.  **Explicit Registration:** Add these manifests to the `resources` list in `apps/overlays/development/kustomization.yaml`.
4.  **Include Legacy Apps:** Ensure the `paulojauregui-com` base deployment is explicitly included by creating an `Application` manifest for it (e.g., `apps/overlays/development/paulojauregui-com-app.yaml`) and adding it to the `kustomization.yaml`.

### Step 2: Harmonize Naming Conventions & Fix Routing
1.  **Rename Root App:** Update the manifest for the apps root (currently in `clusters/home-dev/apps-root.yaml`) to change its name from `dev-app-paulojauregui-com` to `home-dev-apps-root`.
2.  **Update Path:** Ensure this root app points explicitly to `apps/overlays/development`.
3.  **Fix Target Namespace:** Update the destination of `home-dev-apps-root` to deploy into the `argocd` namespace on the Hub cluster (`https://kubernetes.default.svc`), as it is now deploying child `Application` CRDs, not raw workloads.

### Step 3: Standardize the Production Apps Overlay
1.  **Create/Audit Registry:** Ensure `apps/overlays/production/kustomization.yaml` exists.
2.  **Relocate Manifests:** Move `clusters/oci-prod/app.yaml` (the production app registration) to `apps/overlays/production/paulojauregui-com-app.yaml`. Ensure it is formatted as a child `Application`.
3.  **Explicit Registration:** List all production apps in the `kustomization.yaml`.
4.  **Fix Target Namespace:** Update the root production app to target the `argocd` namespace on the Hub.

### Step 4: Cleanup & GitOps Verification
1.  **Remove Obsolete Files:** Delete the now-redundant manifests from the `clusters/` subdirectories.
2.  **Apply Root Changes:** Manually apply the renamed `home-dev-apps-root` to the Hub cluster to "re-parent" the tree.
3.  **Final Sync:** Trigger a full sync in ArgoCD and verify that all applications remain healthy under the new explicit structure.

---

## 4. Success Criteria
*   [ ] **Zero Manual Discovery:** No application depends on ArgoCD's "Directory" source mode without a `kustomization.yaml`.
*   [ ] **Structural Consistency:** The `apps/` directory and `infrastructure/` directory follow the exact same Kustomize overlay pattern.
*   [ ] **Zero Downtime:** The refactoring of the parent-child relationships in ArgoCD does not cause the underlying pods (MLflow, Postgres, etc.) to be deleted or restarted.
*   [ ] **Explicit Registry:** A new engineer can look at a single `kustomization.yaml` in an overlay and see exactly which applications are intended for that cluster.
*   [ ] **Correct Control Plane Routing:** All "App of Apps" root applications correctly deploy their child `Application` manifests into the `argocd` namespace on the Hub cluster.
*   [ ] **Health Check:** All applications in the Hub cluster show as "Synced" and "Healthy".