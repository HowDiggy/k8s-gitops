# My Kubernetes GitOps Repository

This repository contains the complete declarative configuration for my personal infrastructure, managed using GitOps principles with Argo CD. It defines the state of my production, staging, and local development Kubernetes clusters.

## Repository Structure & Workflow

This repository follows a multi-environment layout using Kustomize overlays to manage environment-specific configurations. The core workflow follows a `development -> staging -> production` promotion path.

* **`dev` branch**: All new features and changes are pushed here. This branch is automatically deployed to the **Development** cluster for initial testing.
* **`main` branch**: This branch represents the stable, production-ready state. A pull request from `dev` to `main` is used to promote changes. Merging to `main` automatically deploys to the **Staging** cluster and makes the changes available for **Production**.

```plaintext
k8s-gitops/
├── apps/
│   ├── base/
│   │   ├── paulojauregui-com/
│   │   └── signconnect/
│   └── overlays/
│       ├── development/
│       ├── staging/
│       └── production/
├── clusters/
│   ├── home-dev/
│   ├── staging/
│   └── oci-prod/
└── infrastructure/
    ├── base/
    │   ├── ingress-nginx/
    │   └── ...
    └── overlays/
        ├── development/
        ├── staging/
        └── production/
```

  * **`clusters/`**: This is the entry point for each cluster. The Argo CD instance on a given cluster is pointed to its corresponding directory here (e.g., `oci-prod` or `home-dev`). These directories contain the "App of Apps" manifests that deploy everything else.
  * **`apps/`**: Contains all user-facing applications, like my personal blog and the SignConnect project.
  * **`infrastructure/`**: Contains all platform-level services, such as the ingress controller and certificate manager, managed with Kustomize overlays.
  * **`base/`**: The `base` directories hold the common, environment-agnostic Kubernetes manifests for an application or service.
  * **`overlays/`**: The `overlays` directories contain Kustomize patches and configurations that are specific to an environment (`development`,`staging`, or `production`).

## Clusters Managed

| Cluster         | Environment | Platform                  | Architecture |
| :---------      | :---------- | :------------------------ | :----------- |
| `oci-prod`      | Production  | Oracle Cloud (OKE)        | `arm64`      |
| `k3's staging`  | Staging     | K3s (Lenovo Workstation)  | `amd64`      |
| `docker-desktop`| Development | Docker Desktop (MBP)      | `arm64`      |

## How It Works: GitOps with a Staging Gate

This repository uses the "App of Apps" pattern with a staging environment as a quality gate.

1.  A single root application is manually applied to each cluster, which points to that cluster's path in the `clusters/` directory.
2.  This root app deploys child applications which, in turn, point to the Kustomize overlays for the actual workloads and infrastructure.
3.  When a change is merged to the `main` branch, it is **automatically** deployed to the **Staging** cluster for final validation.
4.  The **Production** cluster's applications have a **manual sync policy**. Argo CD will show them as `OutOfSync`, but will not apply any changes until an operator manually clicks the **Sync** button in the UI. This provides a final safety net before impacting users.

## Managing Environment Differences with Kustomize

Kustomize overlays are used to manage the configuration drift between the production and development environments.

For example, the `paulojauregui-com` application is defined in `apps/base/paulojauregui-com` with settings suitable for production, such as `replicas: 2` and a `nodeSelector` for the `arm64` architecture.

The `apps/overlays/development` directory then applies patches to this base configuration to make it suitable for the local cluster:

  * It reduces the `replicas` to `1`.
  * It changes the `nodeSelector` to target the `amd64` architecture.