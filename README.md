# My Kubernetes GitOps Repository

This repository contains the complete declarative configuration for my personal infrastructure, managed using GitOps principles with Argo CD. It defines the state of both my production and local development Kubernetes clusters.

## Repository Structure

This repository follows a multi-cluster layout using Kustomize to manage environment-specific configurations.

```plaintext
k8s-gitops/
├── apps/
│   ├── base/
│   │   └── paulojauregui-com/
│   └── overlays/
│       ├── development/
│       └── production/
├── clusters/
│   ├── home-dev/
│   └── oci-prod/
├── infrastructure/
    ├── base/
    │   ├── ingress-nginx/
    │   └── cert-manager/
    └── overlays/
        ├── development/
        └── production/
```

  * **`clusters/`**: This is the entry point for each cluster. The Argo CD instance on a given cluster is pointed to its corresponding directory here (e.g., `oci-prod` or `home-dev`). These directories contain the "App of Apps" manifests that deploy everything else.
  * **`apps/`**: Contains all user-facing applications, like my personal blog.
  * **`infrastructure/`**: Contains all platform-level services needed to run the cluster, such as the ingress controller and certificate manager.
  * **`base/`**: The `base` directories hold the common, environment-agnostic Kubernetes manifests for an application or service.
  * **`overlays/`**: The `overlays` directories contain Kustomize patches and configurations that are specific to an environment (`production` or `development`).

## Clusters Managed

| Cluster    | Environment | Platform                  | Architecture |
| :--------- | :---------- | :------------------------ | :----------- |
| `oci-prod` | Production  | Oracle Cloud (OKE)        | `arm64`      |
| `home-dev` | Development | K3s (Lenovo Workstation)  | `amd64`      |

## How It Works: The App of Apps Pattern

This repository uses the "App of Apps" pattern. A single root application is manually applied to each cluster, which points to the cluster's path in the `clusters/` directory. This root application then deploys other applications which, in turn, point to the Kustomize overlays for the actual workloads.

This creates a hierarchical structure that is highly organized and easy to manage.

## Managing Environment Differences with Kustomize

Kustomize overlays are used to manage the configuration drift between the production and development environments.

For example, the `paulojauregui-com` application is defined in `apps/base/paulojauregui-com` with settings suitable for production, such as `replicas: 2` and a `nodeSelector` for the `arm64` architecture.

The `apps/overlays/development` directory then applies patches to this base configuration to make it suitable for the local cluster:

  * It reduces the `replicas` to `1`.
  * It changes the `nodeSelector` to target the `amd64` architecture.