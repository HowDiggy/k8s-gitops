# OCI Migration and Local Cluster Decommissioning Plan

## Overview
This document outlines the step-by-step process to decommission the local Talos cluster (`home-dev`) and migrate workloads to the Oracle Cloud Infrastructure (OCI) cluster (`oci-prod`). The plan is structured around a GitOps "Archive Pattern" to preserve local configurations while updating ArgoCD to target the expanded OCI environment.

### Constraints & Assumptions
- **CNI:** OCI native VCN CNI will be retained. The ~31 pod/node limit applies. Migration to an overlay network (e.g., Cilium) is deferred for a future learning lab.
- **Spark:** `spark-operator` migration is deferred as it is not currently needed.
- **State:** No data migration is needed from the local cluster as it was recently provisioned and is powered off.

---

## 🟢 Milestone 1: The GitOps Archive Pattern (Preserving `home-dev`)
**Status:** Completed

The goal is to cleanly remove the `home-dev` cluster from ArgoCD's crosshairs while preserving all code and manifests for future reference.

- [x] 1. Create directory `archive/home-dev/` at the repository root.
- [x] 2. Create `archive/home-dev/RESTORE_CLUSTER.md` detailing restoration steps.
- [x] 3. Move cluster roots (`clusters/home-dev/*`) to `archive/home-dev/clusters/`.
- [x] 4. Move infrastructure overlays (`infrastructure/overlays/home-dev/`) to `archive/home-dev/infrastructure/`.
- [x] 5. Move application overlays (`apps/overlays/development/` or `apps/overlays/home-dev/` depending on recent structure) to `archive/home-dev/apps/`.

---

## 🟡 Milestone 2: Prepping the OCI Environment (Scaling & Auditing)
**Status:** Pending

Ensure the OCI cluster has the capacity to support the incoming workloads.

- [ ] 1. **User Action:** Provision the 3rd ARM node (2 vCPU, 12GB RAM) in the OCI Console. Wait for it to reach `Ready` status.
- [ ] 2. Audit current pod count on OCI to ensure we have sufficient headroom given the OCI CNI limitations (~31 pods/node, ~93 total).

---

## 🟡 Milestone 3: Migrating Workloads to `oci-prod`
**Status:** In Progress

Port the required applications from the archive to the active OCI overlay.

- [x] 1. Port infrastructure components from the archive to `infrastructure/overlays/oci-prod/`.
  - MongoDB Operator
  - SeaweedFS
  - Qdrant
  - *Note: spark-operator is intentionally excluded.*
- [x] 2. Ensure ARM64 compatibility for all ported workloads.
- [x] 3. Adjust resource requests/limits (CPU/Memory) in `values.yaml` files to fit OCI node constraints (2 vCPU / 12GB RAM per node).
- [x] 4. Ensure OCI CSI driver is used for Persistent Volume Claims (PVCs) instead of local storage.

---

## 🟡 Milestone 4: GitOps Commit and Verification
**Status:** Pending

Commit the changes and let ArgoCD apply them to the OCI cluster.

- [ ] 1. Commit and push all changes to the Git repository.
- [ ] 2. Monitor ArgoCD for successful synchronization of the `oci-prod` applications.
- [ ] 3. Verify PVCs bind successfully to OCI Block Volumes.
- [ ] 4. Verify pod statuses transition to `Running` without `Pending` states caused by resource starvation or pod limits.

---

## 🟡 Milestone 5: Future Labs (Deferred)
**Status:** On Hold

- [ ] Migrate OCI cluster from native VCN CNI to Cilium (overlay mode) to bypass pod limits and introduce Gateway API.
- [ ] Reintroduce Spark Operator if/when needed.
