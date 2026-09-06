# 0002. Gateway API CRD Versioning & GVK Maturity in Cilium 1.20+

* **Status:** Accepted  
* **Date:** 2026-09-05  
* **Scope:** Cluster Bootstrap & CRD Management  
* **Authors:** Paulo Jauregui  

---

## Context and Problem Statement

When enabling Cilium's native Gateway API controller (`gatewayAPI.enabled: true`) in Cilium 1.20.1, the `cilium-operator` failed to start its Gateway reconciliation loops, logging the following error:

```
level=error msg="Required GatewayAPI resources are not found" 
error="CRD \"tlsroutes.gateway.networking.k8s.io\" does not have version \"v1\"" 
subsys=gateway-api
```

Attempts to install Gateway API CRDs using earlier release bundles (`v1.2.0` standard and `v1.2.1` experimental) failed to resolve the issue. We needed to identify the exact GroupVersionKind (GVK) maturity required by Cilium 1.20+ and establish a deterministic bootstrap mechanism.

---

## First-Principles Mental Model & Root Cause Analysis

### 1. Kubernetes API Versioning & Informer Initialization
Kubernetes controllers written in Go use `k8s.io/client-go` Informers to watch custom resources. When a controller initializes, it registers Informers against specific compiled typed schemas (e.g., `gatewayv1.TLSRoute`, `gatewayv1.BackendTLSPolicy`, `gatewayv1.ReferenceGrant`).

If the Kubernetes API Server's registered CustomResourceDefinition (CRD) only advertises `v1alpha2` or `v1beta1` in its `spec.versions`, the controller's Informer factory fails with a schema mismatch error:

```
[ Cilium Operator 1.20+ Go Informer ]
         │
         │ Expects: gateway.networking.k8s.io/v1
         ▼
[ Kubernetes API Server CRD Registration ]
   - TLSRoute: v1alpha2   ❌ (Fails operator startup)
   - TLSRoute: v1         ✅ (Satisfies operator informer)
```

### 2. The Gateway API Release Lifecycle
- **Gateway API v1.2.x**: In these releases, `GatewayClass`, `Gateway`, and `HTTPRoute` were GA (`v1`), but `TLSRoute`, `BackendTLSPolicy`, and `ReferenceGrant` remained in the *experimental* channel (`v1alpha2`/`v1alpha3`).
- **Gateway API v1.5.0**: Graduated `TLSRoute`, `BackendTLSPolicy`, and `ReferenceGrant` to the GA **`v1`** schema within the **standard-install** bundle.

Because Cilium 1.20 compiles against `v1` for these resources, any bundle older than `v1.5.0` causes the operator to halt initialization of its Gateway controller.

---

## Decision

1. **Standardize on Gateway API v1.5.0+ Standard Install**:
   Use the official release manifest:
   `https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml`
2. **Automate CRD Deployment on Day 0**:
   Stage the CRD bundle directly into K3s's auto-deploy manifests directory during control-plane installation:
   `/var/lib/rancher/k3s/server/manifests/01-gateway-api-crds.yaml`
   This ensures CRDs are registered in etcd/SQLite before Cilium's operator or agents ever boot.
3. **Document Version Constraints in Helm Values**:
   Include explicit comments in [`values-cilium.yaml`](file:///Users/paulojauregui/projects/homelab/k3s/values-cilium.yaml) documenting that Cilium 1.20+ requires `v1` GVK schemas for all Gateway resources.

---

## Consequences

### Positive
- **Deterministic Controller Startup**: `cilium-operator` starts cleanly without Informer crashes or missing CRD alerts.
- **Zero Manual `kubectl apply` Steps**: Staged automatically on the control plane during host setup.

### Negative / Operational Caveats
- **Operator Restart Required Upon Late CRD Installation**: Cilium operator checks CRD presence strictly at boot time. If Gateway API CRDs are applied after the operator has already launched, the deployment must be restarted explicitly:
  ```bash
  kubectl rollout restart deploy -n kube-system cilium-operator
  ```
