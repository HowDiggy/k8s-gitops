# 0005. Infrastructure Dependency Resolution & Pre-Flight Research Protocol

* **Status:** Accepted  
* **Date:** 2026-09-06  
* **Scope:** Repository-Wide Engineering Standards & AI Pair-Programming  
* **Authors:** Paulo Jauregui  

---

## Context and Problem Statement

Modern Kubernetes platform infrastructure consists of a deeply interconnected, multi-layered dependency graph:
- Operating System kernel capabilities & eBPF versions
- Kubernetes API Server minor version
- CustomResourceDefinitions (CRDs) and their served/stored GroupVersionKind (GVK) schemas
- In-cluster controllers and operators (Cilium, cert-manager, External Secrets Operator, ArgoCD)
- Downstream application routing contracts (Gateway API, HTTPRoutes)

In software development, package managers (such as `poetry` for Python or `cargo` for Rust) systematically construct a dependency graph, check semantic version constraints across all transitive dependencies, and generate a deterministic lockfile before any code executes. 

Conversely, infrastructure engineering often suffers from ad-hoc, unverified version selection—relying on memory, outdated examples, or guesswork. This was demonstrated during this session when deploying Gateway API CRDs for Cilium 1.20: earlier CRD bundles (`v1.2.0` standard and `v1.2.1` experimental) lacked the `v1` GA schemas required by the compiled controller, causing Informer crashes and requiring three deployment iterations.

---

## First-Principles Mental Model: Infrastructure Dependency Resolution

Infrastructure components must be treated with the exact same dependency rigor as software packages:

```
[ Application / Gateway Manifest ]
               │
               ▼
[ Operator / Controller Informer ]   (Requires specific compiled Go types, e.g., TLSRoute/v1)
               │
               ▼
[ CustomResourceDefinition (CRD) ]   (Must serve matching GVK in spec.versions)
               │
               ▼
[ Kubernetes API Server ]            (Admission, schema validation, OpenAPI defaulting)
               │
               ▼
[ Host Linux Kernel & eBPF ]         (Kernel version, XDP/tc hook support, socket maps)
```

A failure at any interface in this stack cascades into controller reconciliation failures, schema defaulting diffs, or silent network packet drops.

---

## Decision

We establish the **Pre-Flight Research & Dependency Resolution Protocol** as a mandatory standard for all infrastructure changes across this repository:

### 1. Mandatory Upstream Research Prior to Code Generation
Before generating, modifying, or proposing any infrastructure manifest (CRDs, Helm values, operators, CNI/CSI plugins):
- A targeted web and documentation search **must be performed** to identify the latest stable, non-experimental release.
- Unverified, guessed, or recalled version numbers are strictly prohibited.

### 2. Transitive Compatibility & GVK Verification
Analogous to a package manager solving a version constraint problem, the dependency chain must be validated prior to execution:
- **Kubernetes Version Compatibility**: Verify that the component officially supports the target cluster's Kubernetes minor version (e.g., K3s `v1.36`).
- **GVK Maturity & Served Versions**: Audit the exact API versions expected by the controller (e.g., `v1` vs. `v1alpha2`/`v1beta1`) and confirm the CRD bundle serves those versions.
- **Kernel / Hardware Constraints**: Verify that host Linux kernels and interfaces satisfy controller prerequisites (e.g., Ubuntu 26.04 kernel 7.0 eBPF map limits, interface regex `^en.*`).

### 3. Upstream Documentation Review
Consult official vendor documentation specifically for:
- Breaking schema changes between minor/major versions.
- Controller initialization requirements (e.g., whether CRDs must exist before operator startup).
- Mutating admission behaviors and schema defaulting keys that could trigger ArgoCD `OutOfSync` false positives.

---

## Consequences

### Positive
- **Elimination of Trial-and-Error Iterations**: Avoids wasted cycles applying incompatible CRD bundles or debugging operator Informer crashes.
- **Deterministic GitOps Syncs**: Manifests are authored with correct schema defaults on the first commit.
- **Permanent Assistant Alignment**: Codified directly into [`GEMINI.md`](file:///Users/paulojauregui/projects/k8s-gitops/GEMINI.md) to govern all future assistant interactions.

### Negative / Operational Tradeoffs
- **Minor Research Latency**: Requires spending 1–2 minutes gathering documentation before proposing or generating infrastructure code, which is vastly outweighed by avoiding runtime debugging.
