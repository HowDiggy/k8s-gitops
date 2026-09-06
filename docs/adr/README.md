# Architecture Decision Records (ADRs)

This directory serves as the definitive log of significant architectural and infrastructure decisions across our multi-cluster Kubernetes GitOps repository.

Decisions are recorded using a structured format documenting the architectural context, evaluated options, first-principles rationale, and operational consequences.

---

## Index of Decisions

| ADR | Title | Date | Status | Scope |
| :--- | :--- | :--- | :--- | :--- |
| [0001](file:///Users/paulojauregui/projects/k8s-gitops/docs/adr/0001-gateway-api-cilium-l2-ingress.md) | Standardize on Kubernetes Gateway API & Cilium Native Ingress with L2 Announcements | 2026-09-05 | **Accepted** | Home K3s Cluster Networking |
| [0002](file:///Users/paulojauregui/projects/k8s-gitops/docs/adr/0002-gateway-api-crd-versioning.md) | Gateway API CRD Versioning & GVK Maturity in Cilium 1.20+ | 2026-09-05 | **Accepted** | Cluster Bootstrap & CRD Management |
| [0003](file:///Users/paulojauregui/projects/k8s-gitops/docs/adr/0003-tainted-control-plane-autonomous-bootstrap.md) | Transition to Tainted Control Plane with Local Agent for Autonomous CNI Bootstrapping | 2026-09-05 | **Accepted** | Bare-Metal Node Topology |
| [0004](file:///Users/paulojauregui/projects/k8s-gitops/docs/adr/0004-declarative-argocd-overlay-and-schema-defaults.md) | Declarative ArgoCD Configuration Overlays, Doppler ESO Sync, and Schema Defaulting | 2026-09-05 | **Accepted** | GitOps Operations & Security |

---

## ADR Template Reference

When authoring new records, follow this lifecycle structure:

- **Title**: `NNNN-short-descriptive-title.md`
- **Status**: Proposed | Accepted | Deprecated | Superseded by [NNNN](link)
- **Context**: Problem statement, business/technical drivers, environment constraints.
- **Mental Model & Considered Alternatives**: First-principles analysis of evaluated approaches.
- **Decision**: Explicit statement of what is adopted or altered.
- **Consequences**: Positive architectural outcomes, negative operational tradeoffs, operational caveats.
