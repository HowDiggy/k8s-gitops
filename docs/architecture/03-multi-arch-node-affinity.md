# Multi-Architecture Node Affinity

## The Concept
Our hybrid cloud architecture utilizes different CPU architectures:
*   **OCI Hub Cluster:** Runs on managed ARM nodes (`arm64`).
*   **Local Talos Spoke Cluster:** Runs on AMD/Intel nodes (`amd64`).

## The Challenge
When creating base configurations (`infrastructure/base/`), it's common to hardcode node selectors for the primary environment. For instance, the base `cert-manager` values were configured for the OCI Hub:

```yaml
# infrastructure/base/cert-manager/values.yaml
nodeSelector:
  kubernetes.io/arch: "arm64"
```

When this base was deployed to the local Talos cluster, the Kubernetes scheduler rejected the pods with a `FailedScheduling` error because the local nodes are labeled `kubernetes.io/arch=amd64`.

## The Solution
Base configurations should be overridden in the specific environment overlays. 

For the local cluster, we create an overlay values file that overrides the `nodeSelector` to target `amd64`.

```yaml
# infrastructure/overlays/home-dev/cert-manager-values.yaml
nodeSelector:
  kubernetes.io/arch: "amd64"

webhook:
  nodeSelector:
    kubernetes.io/arch: "amd64"

cainjector:
  nodeSelector:
    kubernetes.io/arch: "amd64"
```

This overlay file is then appended to the `helm.valueFiles` list in the ArgoCD `Application` manifest:

```yaml
      helm:
        valueFiles:
          - $values/infrastructure/base/cert-manager/values.yaml
          - $values/infrastructure/overlays/home-dev/cert-manager-values.yaml
```
This ensures that the same base configuration can be adapted for any architecture simply by applying the correct overlay.
