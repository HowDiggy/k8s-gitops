# 0001. Standardize on Kubernetes Gateway API & Cilium Native Ingress with L2 Announcements

* **Status:** Accepted  
* **Date:** 2026-09-05  
* **Scope:** Home K3s Cluster Networking  
* **Authors:** Paulo Jauregui  

---

## Context and Problem Statement

On-premise Kubernetes clusters running on bare-metal hardware do not have access to cloud-provider load balancers (such as AWS NLB or Azure ALB). To access internal services like the ArgoCD web interface, engineers typically rely on `kubectl port-forward`, host-level port binding via `NodePort`, or deploying third-party ingress controllers (Ingress-NGINX, Traefik).

We required a production-grade networking solution to expose in-cluster interfaces over standard ports (`80` and `443`) on the local LAN (`192.168.1.0/24`) at `https://argocd.homelab.local` without manual tunnels or unnecessary controller overhead on resource-constrained laptop worker nodes.

---

## First-Principles Mental Model & Evaluated Alternatives

### 1. The Gateway API vs. Ingress Mental Model
The traditional `networking.k8s.io/v1` `Ingress` API conflated infrastructure provision, TLS termination, and routing rules into a single flat manifest, requiring vendor-specific annotations for basic operations like HTTP-to-HTTPS redirects. Furthermore, the Ingress API is functionally frozen upstream.

The **Kubernetes Gateway API** (`gateway.networking.k8s.io`) establishes a role-oriented, decoupled hierarchy:
- **`GatewayClass`**: Platform/vendor definition (Cilium).
- **`Gateway`**: Infrastructure definition (IP address, listening ports 80/443, TLS secret references). Managed by the infrastructure engineer.
- **`HTTPRoute`**: Application routing contract (path matching, header manipulation, 301 redirects, backend destination). Managed by the application owner.

### 2. Evaluated Ingress Engines
1. **Standalone Ingress Controllers (Ingress-NGINX / Traefik)**:
   - *Architecture*: Separate deployment pods, replica sets, and Services running in user-space.
   - *Downside*: Extra memory footprint and additional network hops across the CNI overlay before reaching the backend pod.
2. **Envoy Gateway (Standalone Control Plane + Envoy Proxy)**:
   - *Architecture*: Dedicated Envoy Gateway controller pods managing an external Envoy daemonset.
   - *Downside*: High resource utilization redundant with existing Cilium infrastructure.
3. **Cilium Native Gateway API**:
   - *Architecture*: Leverages the embedded Envoy proxy already running inside `cilium-agent` daemonsets. eBPF programs on host interfaces perform Layer 4 socket lookups and dispatch traffic directly to the internal Envoy listener without traversing iptables or extra network hops.
   - *Outcome*: Selected as the optimal architecture.

### 3. Layer 2 Announcement Mental Model
Without BGP routing hardware on the home router, we require Layer 2 ARP broadcasts to map the floating LoadBalancer Virtual IP (`192.168.1.60`) to physical host MAC addresses.

```
                   [ Home LAN Router: 192.168.1.1 ]
                                  │
                  ARP Query: "Who has 192.168.1.60?"
                                  ▼
      ┌────────────────────────────────────────────────────────┐
      │               Worker Nodes (L2 Policy)                 │
      │                                                        │
      │   Node: dito (192.168.1.58)  Node: beet (192.168.1.59)  │
      │   [Lease Holder: ACTIVE]     [Standby Backup]          │
      │   ARP Reply: MAC(dito)       (Silent)                  │
      └────────────────────────────────────────────────────────┘
```

- Cilium uses a Kubernetes `Lease` object in `kube-system` to elect an active announcer node.
- The elected node answers ARP requests for the VIP on its physical interface (`enp0s31f6` matching `^en.*`).
- If the leader fails, the surviving worker acquires the lease and immediately assumes ARP answering, providing bare-metal high availability.

---

## Decision

1. **Adopt Kubernetes Gateway API** with `gatewayClassName: cilium` as the universal ingress standard for the Home K3s cluster.
2. **Enable Cilium Gateway API Controller & L2 Announcements**:
   - Enable `gatewayAPI.enabled: true` and `l2announcements.enabled: true` in [`values-cilium.yaml`](file:///Users/paulojauregui/projects/homelab/k3s/values-cilium.yaml).
3. **Allocate LoadBalancer VIP Pool**:
   - Reserve static pool `192.168.1.60 - 192.168.1.69` via `CiliumLoadBalancerIPPool`, strictly isolated from the router's DHCP pool (`192.168.1.100 - 192.168.1.200`).
4. **Isolate Announcements to Worker Nodes**:
   - The `CiliumL2AnnouncementPolicy` explicitly targets `node-role.kubernetes.io/worker`. The control plane node (`tiny`) is excluded from ARP responder duties.
5. **Implement Dual-HTTPRoute Architecture**:
   - One `HTTPRoute` on port 80 performing a native `RequestRedirect` (301) to HTTPS.
   - One `HTTPRoute` on port 443 routing traffic to the backend Service (`argocd-server:80`).
6. **Offload TLS Termination at the Gateway**:
   - Envoy terminates TLS using certificates issued by cert-manager `self-signed-issuer`.
   - ArgoCD server runs in `server.insecure: "true"` mode to prevent double-encryption overhead.

---

## Consequences

### Positive
- **Zero Additional Proxy Pods**: Eliminated the need for NGINX or Traefik pods, saving ~300MB–500MB of RAM across workers.
- **Hardware-Level Redundancy**: Automatic ARP failover between worker laptops (`dito` and `beet`).
- **Declarative & GitOps Native**: All routing, certificates, and IP pools are declared in [`infrastructure/base/gateway/`](file:///Users/paulojauregui/projects/k8s-gitops/infrastructure/base/gateway/kustomization.yaml).

### Negative / Operational Caveats
- **The ICMP (Ping) Fallacy**: `ping 192.168.1.60` will fail with packet drops or "Destination Host Unreachable." Cilium eBPF only programs kernel redirect rules for ports explicitly declared in the Kubernetes `Service` spec (TCP 80, 443). ICMP echo requests have no socket mapping and are dropped. Connectivity must be validated using Layer 4/7 tools (`curl`, `nc`).
- **CRD Dependency**: Requires Gateway API CRDs to be present at `v1` prior to controller startup (see [ADR 0002](file:///Users/paulojauregui/projects/k8s-gitops/docs/adr/0002-gateway-api-crd-versioning.md)).
