# KubeVirt Decommissioning Plan

This plan outlines the safe removal of the KubeVirt infrastructure and the networking lab VMs from the cluster to alleviate thermal load on the nodes.

## Phase 1: Remove Workloads
1.  **Delete the ArgoCD Application:** Delete the `networking-lab-workloads` Application from ArgoCD. This will cascade and delete the 4 `VirtualMachine` resources, which will gracefully terminate the `VirtualMachineInstances` and their underlying `virt-launcher` pods.
    *   *GitOps Action:* Remove the `networking-lab-workloads` entry from `apps/overlays/home/kustomization.yaml`.
2.  **Verify Removal:** Ensure the `networking-lab` namespace is empty of pods (`kubectl get pods -n networking-lab`).

## Phase 2: Remove Infrastructure
1.  **Remove KubeVirt Operator:** Delete the `kubevirt` Application from the infrastructure root.
    *   *GitOps Action:* Remove `kubevirt.yaml` from `infrastructure/overlays/home/kustomization.yaml`.
2.  **Remove Multus (Optional):** If Multus was solely deployed to support KubeVirt bridge networking, it can also be removed.
    *   *GitOps Action:* Remove `multus.yaml` from `infrastructure/overlays/home/kustomization.yaml`.

## Phase 3: Cleanup Configurations
1.  **Remove ArgoCD Health Checks:** Clean up the `argocd-cm` ConfigMap to remove the Lua health checks we added for `Pod`, `VirtualMachine`, and `VirtualMachineInstance`.
    *   *GitOps Action:* Edit `infrastructure/base/argocd/argocd-cm.yaml` to revert to the default state.

## Phase 4: Commit and Sync
1.  Commit all changes to Git.
2.  Push to `main`.
3.  Allow ArgoCD to synchronize and prune the deleted resources from the cluster.