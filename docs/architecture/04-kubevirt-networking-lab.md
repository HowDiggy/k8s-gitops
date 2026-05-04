# KubeVirt Networking Lab Architecture

This document details the architecture and operational usage of the KubeVirt-based Networking Lab deployed within the Talos Kubernetes cluster. This lab provides a completely isolated, GitOps-managed environment for practicing advanced networking concepts (routing, firewalling, VPNs) without risking the stability of the underlying infrastructure.

## 1. Architectural Overview

The lab utilizes a "Two-Site" topology, simulating two distinct branch offices connecting over a Wide Area Network (WAN). The underlying Kubernetes pod network acts as the WAN, while Multus CNI provides isolated Layer-2 broadcast domains for the local area networks (LANs).

### The Technology Stack
*   **KubeVirt:** Runs full Linux operating systems (Ubuntu 22.04) as standard Kubernetes Pods via KVM.
*   **Multus CNI:** A meta-CNI that allows Virtual Machine Pods to have multiple network interfaces (`eth0`, `eth1`, etc.), bridging them to isolated virtual switches.
*   **ContainerDisks:** Ephemeral, stateless boot disks pulled directly from a container registry (`quay.io/containerdisks/ubuntu:22.04`), ensuring the lab starts from a clean slate upon every restart.
*   **Cloud-Init:** Bootstraps the VMs with specific IP addresses, routing rules, and `iptables` configurations automatically upon launch.

---

## 2. Network Topology

### The "WAN" (Kubernetes Pod Network)
*   The default Kubernetes CNI (e.g., Flannel/Cilium) acts as the public internet/WAN.
*   The "Router" VMs are connected to this network via their `eth0` interfaces.
*   The Router VMs perform Source NAT (Masquerade) so internal clients can reach the actual internet.

### Site 1
*   **Virtual Switch:** `br-lab` (Multus `NetworkAttachmentDefinition`)
*   **LAN Subnet:** `192.168.100.0/24`
*   **Router VM (`router-vm`):**
    *   `eth0` (WAN): DHCP from Kubernetes Pod Network.
    *   `eth1` (LAN): `192.168.100.1` (Gateway for Site 1).
*   **Client VM (`ubuntu-client`):**
    *   `eth0` (LAN): `192.168.100.10`

### Site 2
*   **Virtual Switch:** `br-lab-site2` (Multus `NetworkAttachmentDefinition`)
*   **LAN Subnet:** `192.168.200.0/24`
*   **Router VM (`router-vm-site2`):**
    *   `eth0` (WAN): DHCP from Kubernetes Pod Network.
    *   `eth1` (LAN): `192.168.200.1` (Gateway for Site 2).
*   **Client VM (`ubuntu-client-site2`):**
    *   `eth0` (LAN): `192.168.200.10`

---

## 3. How It Works (Traffic Flow)

When `ubuntu-client` (Site 1) pings an external IP (e.g., `8.8.8.8`):
1.  **Client:** The packet leaves `ubuntu-client` and travels across the isolated `br-lab` virtual bridge to its configured gateway: `192.168.100.1` (The Router).
2.  **Router Ingress:** The `router-vm` receives the packet on its `eth1` (LAN) interface.
3.  **NAT/Routing:** Because `ip_forward=1` is enabled, the Router's kernel routes the packet to `eth0` (WAN). An `iptables` MASQUERADE rule rewrites the source IP to match the Router's WAN IP.
4.  **Egress:** The packet exits the VM, enters the standard Kubernetes network, and relies on the Talos node to route it to the actual internet.

---

## 4. Operational Guide (How to Use the Lab)

All resources reside in the `networking-lab` namespace.

### Accessing the VMs
You must use the `virtctl` CLI tool to connect to the serial console of the VMs.

```bash
# Ensure you are targeting the Talos cluster
export KUBECONFIG=./.kubeconfig-talos

# List the VMs and their states
kubectl get vmi -n networking-lab -o wide

# Connect to Site 1 Client
virtctl console ubuntu-client -n networking-lab

# Connect to Site 2 Router
virtctl console router-vm-site2 -n networking-lab
```
*Default Credentials for all VMs:*
*   **User:** `ubuntu`
*   **Password:** `password`

### Resetting the Lab
Because the VMs use `ContainerDisks`, they are stateless. If you misconfigure a routing table or lock yourself out with a firewall rule, simply delete the VirtualMachineInstance (VMI). KubeVirt will immediately spin up a fresh one using the GitOps-defined `cloud-init` state.

```bash
kubectl delete vmi router-vm -n networking-lab
```

---

## 5. Practice Scenarios

This topology is specifically designed to practice the following:

1.  **Static Routing:** Configure the `router-vm` to reach `192.168.200.0/24` by pointing a static route at the WAN IP of `router-vm-site2`.
2.  **Site-to-Site VPNs:** Install WireGuard on both routers. Establish an encrypted tunnel over the Kubernetes WAN so `ubuntu-client` can securely communicate with `ubuntu-client-site2`.
3.  **Firewalling (Access Control):** Use `iptables` or `ufw` on the routers to block inter-site traffic while allowing general internet access.
4.  **Port Forwarding (Destination NAT):** Run a Python HTTP server on `ubuntu-client-site2` and configure `router-vm-site2` to forward incoming WAN traffic on port 8080 to the internal client.

## GitOps Implementation Details
*   **Manifests Location:** `apps/base/networking-lab/` and `infrastructure/base/networking-lab/`
*   **Multus CNI:** Deployed as a DaemonSet in `kube-system` (`infrastructure/base/multus/`).
*   **KubeVirt Operator:** Deployed in the `kubevirt` namespace (`infrastructure/base/kubevirt/`).
