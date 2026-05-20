# GitOps Restructuring Plan: Shift to Physical Mapping

## Objective
Migrate the repository structure from logical environments (`development`, `staging`, `production`) to physical/provider-based environments (`home`, `azure`, `oci`). This simplifies GitOps management and better reflects the actual footprint of the infrastructure.

## Scope of Changes

### 1. The `home` Environment
The archived `home-dev` cluster will be restored and renamed to `home`.
- **Cluster Root:** `git mv archive/home-dev/clusters/home-dev clusters/home`
- **Infrastructure:** `git mv archive/home-dev/infrastructure/home-dev infrastructure/overlays/home`
- **Applications:** `git mv archive/home-dev/apps/development apps/overlays/home`
- **Updates:** Update ArgoCD manifests in `clusters/home/` to point to the new paths.

### 2. The `azure` Environment
The `azure-prod` cluster will be renamed to `azure`.
- **Cluster Root:** `git mv clusters/azure-prod clusters/azure`
- **Infrastructure:** `git mv infrastructure/overlays/azure-prod infrastructure/overlays/azure`
- **Applications:** `git mv apps/overlays/azure-prod apps/overlays/azure`
- **Updates:** Update ArgoCD manifests in `clusters/azure/` to point to the new paths.

### 3. The `oci` Environment
The `oci-prod` cluster currently uses `production` overlays. It will be consolidated into `oci`.
- **Cluster Root:** `git mv clusters/oci-prod clusters/oci`
- **Infrastructure:** `git mv infrastructure/overlays/production infrastructure/overlays/oci`
- **Applications:** `git mv apps/overlays/production apps/overlays/oci`
- **Cleanup:** Delete `infrastructure/overlays/oci-prod/` (it appears to be partially used or abandoned, we will verify its contents before deletion. Wait, `oci-prod` cluster uses `production` overlays? Let's check which is which). 
  - Actually, `clusters/oci-prod/infra.yaml` points to `production`. We will merge any unique configs from `infrastructure/overlays/oci-prod/` (if valid) or just delete it if `production` was the active one.
- **Updates:** Update ArgoCD manifests in `clusters/oci/` to point to `infrastructure/overlays/oci` and `apps/overlays/oci`.

### 4. Cleanup of Deprecated Logical Environments
Once the above are mapped, the following deprecated semantic overlays will be deleted:
- `clusters/staging/`
- `apps/overlays/staging/`
- `infrastructure/overlays/staging/`
- `infrastructure/overlays/development/`
- `archive/home-dev/`

### 5. Reference Verification
Run global search and replace to ensure all `path:` and `$values/` references within the ArgoCD application manifests and `kustomization.yaml` files correctly point to the new `/home`, `/azure`, and `/oci` directories.
