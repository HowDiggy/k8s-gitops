# [COMPLETED] GitOps Pattern Standardization Plan: Explicit Kustomize for Applications

## 1. Objective
Converge the "Applications" layer of the GitOps repository onto the **Explicit Kustomize Pattern**. This eliminates directory-based "magic" discovery and ensures every application is explicitly registered in a Kustomize resource tree, matching the established pattern used in the "Infrastructure" layer.

## 2. Status: COMPLETED (April 25, 2026)
All applications across Development, Staging, and Production have been migrated to the explicit registry pattern. Root applications have been re-parented to the Hub cluster's `argocd` namespace.

---

## 3. Step-by-Step Implementation

### Step 1: Standardize the Development Apps Overlay [DONE]
1.  **Create Registry:** Create `apps/overlays/development/kustomization.yaml`.
2.  **Relocate Manifests:** Move application registration manifests from `clusters/home-dev/` into the overlay:
    *   `clusters/home-dev/app-mlflow.yaml` -> `apps/overlays/development/mlflow-app.yaml`
3.  **Explicit Registration:** Add these manifests to the `resources` list in `apps/overlays/development/kustomization.yaml`.
4.  **Include Legacy Apps:** Ensure the `paulojauregui-com` base deployment is explicitly included by creating an `Application` manifest for it (e.g., `apps/overlays/development/paulojauregui-com-app.yaml`) and adding it to the `kustomization.yaml`.

### Step 2: Harmonize Naming Conventions & Fix Routing [DONE]
1.  **Rename Root App:** Update the manifest for the apps root (currently in `clusters/home-dev/apps-root.yaml`) to change its name from `dev-app-paulojauregui-com` to `home-dev-apps-root`.
2.  **Update Path:** Ensure this root app points explicitly to `apps/overlays/development`.
3.  **Fix Target Namespace:** Update the destination of `home-dev-apps-root` to deploy into the `argocd` namespace on the Hub cluster (`https://kubernetes.default.svc`), as it is now deploying child `Application` CRDs, not raw workloads.

### Step 3: Standardize the Production Apps Overlay [DONE]
1.  **Create/Audit Registry:** Ensure `apps/overlays/production/kustomization.yaml` exists.
2.  **Relocate Manifests:** Move `clusters/oci-prod/app.yaml` (the production app registration) to `apps/overlays/production/paulojauregui-com-app.yaml`. Ensure it is formatted as a child `Application`.
3.  **Explicit Registration:** List all production apps in the `kustomization.yaml`.
4.  **Fix Target Namespace:** Update the root production app to target the `argocd` namespace on the Hub.

### Step 4: Cleanup & GitOps Verification [DONE]
1.  **Remove Obsolete Files:** Delete the now-redundant manifests from the `clusters/` subdirectories.
2.  **Apply Root Changes:** Manually apply the renamed `home-dev-apps-root` to the Hub cluster to "re-parent" the tree.
3.  **Final Sync:** Trigger a full sync in ArgoCD and verify that all applications remain healthy under the new explicit structure.

---

## 4. Success Criteria
*   [x] **Zero Manual Discovery:** No application depends on ArgoCD's "Directory" source mode without a `kustomization.yaml`.
*   [x] **Structural Consistency:** The `apps/` directory and `infrastructure/` directory follow the exact same Kustomize overlay pattern.
*   [x] **Zero Downtime:** The refactoring of the parent-child relationships in ArgoCD does not cause the underlying pods (MLflow, Postgres, etc.) to be deleted or restarted.
*   [x] **Explicit Registry:** A new engineer can look at a single `kustomization.yaml` in an overlay and see exactly which applications are intended for that cluster.
*   [x] **Correct Control Plane Routing:** All "App of Apps" root applications correctly deploy their child `Application` manifests into the `argocd` namespace on the Hub cluster.
*   [x] **Health Check:** All applications in the Hub cluster show as "Synced" and "Healthy".