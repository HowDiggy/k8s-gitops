# Hub-and-Spoke GitOps Architecture (App of Apps)

## Concept
The project utilizes a Hub-and-Spoke model managed by ArgoCD.
*   **Hub:** The OCI Cloud Cluster. Runs ArgoCD and acts as the central control plane.
*   **Spoke:** The Local Talos Cluster (and future clusters). Runs workloads.

To manage this declaratively, we use the **App of Apps** pattern.

## The Architecture
1.  **The Registry (`infrastructure/overlays/<env>/kustomization.yaml`):** 
    This acts as the single source of truth for all applications that belong in a specific environment. It ONLY contains references to ArgoCD `Application` manifests (e.g., `spark-operator.yaml`, `cert-manager.yaml`).
2.  **The Root App (`clusters/<env>/infra-root.yaml`):**
    This is the primary "App of Apps". It is deployed on the **Hub**. Its sole job is to point at the Registry directory and deploy all those `Application` manifests into the Hub cluster itself.
3.  **The Child Apps:**
    Once the Hub cluster receives the `Application` manifests from the Root App, ArgoCD wakes up, reads them, and deploys the actual workloads (Helm charts, Kustomizations) to their specified `destination.server` (the **Spoke** cluster).

## Important Rules
*   **No Raw Resources in the Registry:** Never put raw Kubernetes manifests (like a `ClusterIssuer` or a `Namespace`) directly into the Registry directory. The Root App will mistakenly deploy them to the Hub cluster instead of the Spoke.
*   **Encapsulation:** If you need a raw resource (like a `ClusterIssuer`), create a dedicated base directory for it (e.g., `infrastructure/base/cert-manager-issuers`), and create an ArgoCD `Application` manifest that points to that base directory. Then, add that `Application` manifest to the Registry.
