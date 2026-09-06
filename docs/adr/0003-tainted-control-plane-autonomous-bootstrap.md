# 0003. Transition to Tainted Control Plane with Local Agent for Autonomous CNI Bootstrapping

* **Status:** Accepted  
* **Date:** 2026-09-05  
* **Scope:** Bare-Metal Node Topology  
* **Authors:** Paulo Jauregui  

---

## Context and Problem Statement

The dedicated control plane node (`tiny` — Intel Core i3-5005U, 2 cores / 4 threads, 8GB RAM, 500GB SSD) was originally configured as an **agentless server** (`disable-agent: true`) with `CriticalAddonsOnly=true:NoExecute`. This was chosen under a conservative assumption that running a container runtime on a fanless mini-PC might starve the API server of memory or CPU cycles.

However, the agentless topology introduced a critical bootstrap circular dependency:
1. An agentless control plane runs no `kubelet` and no `containerd`. It is physically incapable of running a container.
2. When deploying Cilium with `flannel-backend: "none"`, the cluster has no CNI.
3. K3s's built-in `helm-controller` dispatches Helm chart installation via transient Kubernetes Job pods (`klipper-helm`).
4. Because `tiny` could not run pods, K3s could not execute its own Helm controller jobs locally. The cluster had to sit idle until remote worker laptops (`dito`, `beet`) joined.
5. Furthermore, worker nodes joining without a CNI showed status `NotReady` ("CNI plugin not initialized"), complicating Day-0 automation.

---

## First-Principles Mental Model & Telemetry Analysis

### 1. Bare-Metal Telemetry Profiling
Before making architectural changes, we profiled `tiny`'s resource consumption over **5 days, 19 hours of continuous uptime**:

| Metric | Measured Value | Analysis |
|:---|:---|:---|
| **CPU Utilization** | **93% – 97% idle** | Load average `0.39, 0.28, 0.27` across 4 threads (<10% load) |
| **Total Memory** | 7.2 GiB | Hardware capacity |
| **Memory Used** | 2.1 GiB | `k3s-server` process using ~1.7 GiB |
| **Memory Available** | **5.1 GiB** | **~71% of physical RAM was completely unutilized** |
| **Thermals** | 27.8°C / 29.8°C / 45.0°C | Fanless chassis running completely cool |

The data disproved the resource starvation hypothesis. `tiny` had massive compute and memory headroom.

### 2. Workload Isolation: Agentless vs. Tainted Local Agent
The purpose of the agentless mode was workload isolation. However, in Kubernetes, **Taints and Tolerations** provide mathematical scheduling guarantees without disabling the node's local container engine:

```
[ Incoming Pod ]
       │
       ▼
[ Kubernetes Scheduler ]
       │
       ├─ Regular App Pod (PostgreSQL, Spark, MLflow)
       │  └─ Has no toleration for control-plane taint → ❌ Rejected from tiny
       │
       └─ System / Bootstrap Pod (Cilium Agent, K3s Helm Job)
          └─ Has toleration `operator: Exists` → ✅ Scheduled on tiny
```

By enabling the local agent on `tiny` and applying the taint `node-role.kubernetes.io/control-plane:NoSchedule`:
- `tiny` gains the ability to execute K3s bootstrap Jobs and the Cilium CNI agent locally.
- Regular user workloads remain 100% blocked from scheduling on `tiny`.

---

## Decision

1. **Enable Local Agent on `tiny`**:
   Remove `disable-agent: true` from `/etc/rancher/k3s/config.yaml`.
2. **Apply Control-Plane Taint**:
   Configure `node-taint: ["node-role.kubernetes.io/control-plane:NoSchedule"]` in `/etc/rancher/k3s/config.yaml`.
3. **Revert Egress Selector Override**:
   Remove `egress-selector-mode: "cluster"`. With the local agent active, K3s standard tunnel routing operates natively.
4. **Implement Option B Auto-Deploy Manifests**:
   In [`install_control_plane.sh`](file:///Users/paulojauregui/projects/homelab/k3s/install_control_plane.sh), stage Gateway API CRDs (`01-gateway-api-crds.yaml`) and the Cilium `HelmChart` manifest (`02-cilium.yaml`) directly into `/var/lib/rancher/k3s/server/manifests/`.

---

## Consequences

### Positive
- **Autonomous Day-0 Self-Bootstrapping**: `tiny` starts K3s, applies Gateway API CRDs, runs `helm-install-cilium`, initializes eBPF on `enp1s0`, and achieves `Ready` status completely independently—before any worker laptops even boot up.
- **Node Visibility**: `tiny` is registered in `kubectl get nodes -o wide` with role `control-plane`.
- **Negligible Resource Cost**: Measured RAM usage on `tiny` increased by only **~100MB** (from 2.1 GiB to 2.2 GiB), leaving **5.0 GiB completely free**.
- **Zero Imperative CLI Steps**: Eliminates manual `helm install` and `kubectl apply` commands during cluster creation.

### Negative / Operational Caveats
- **Cilium DaemonSet Expansion**: Cilium agent now runs on 3 nodes instead of 2. It compiles eBPF maps and monitors interface `enp1s0` on `tiny`, consuming ~400MB of RAM on the control plane.
- **Taint Discipline**: Any future platform daemonset (e.g., node-exporter, Promtail) will only run on `tiny` if explicitly equipped with control-plane tolerations.
