# KubeVirt Networking Lab Implementation Plan

This document outlines the phased approach to deploying a virtualized networking lab (VyOS Router + Ubuntu Client) within the existing Talos/ArgoCD GitOps environment using KubeVirt and Multus CNI.

## Objective
To create a fully functional, GitOps-managed environment for practicing networking concepts (routing, firewalling, multi-homed networking) using VMs running natively inside Kubernetes.

---

## Milestone 1: Multus CNI Deployment (The Networking Foundation)
*Goal: Enable pods and VMs to have multiple network interfaces, which is essential for routing between different virtual networks.*

*   **Task 1.1:** Research the official Multus CNI manifests compatible with Talos OS.
*   **Task 1.2:** Add Multus CNI to `infrastructure/base/multus`.
*   **Task 1.3:** Update `infrastructure/base/kustomization.yaml` to include Multus.
*   **Task 1.4:** Wait for ArgoCD to sync and verify Multus DaemonSet is running on all Talos nodes.

---

## Milestone 2: KubeVirt Operator Deployment
*Goal: Install the platform required to run Virtual Machines natively on Kubernetes.*

*   **Task 2.1:** Research the latest stable release of KubeVirt.
*   **Task 2.2:** Add the KubeVirt Operator and KubeVirt Custom Resource manifests to `infrastructure/base/kubevirt`.
*   **Task 2.3:** Update `infrastructure/base/kustomization.yaml` to include KubeVirt.
*   **Task 2.4:** Wait for ArgoCD to sync and verify the KubeVirt operator and virt-api/virt-controller pods are running.
*   **Task 2.5:** Validate that the KubeVirt `Virtctl` binary or equivalent functionality is accessible to manage VMs (optional but recommended for interacting with serial consoles).

---

## Milestone 3: L2 Virtual Networking Setup
*Goal: Create an isolated Layer-2 virtual network (bridge) for the VMs to communicate over, independent of the primary Kubernetes pod network.*

*   **Task 3.1:** Define a `NetworkAttachmentDefinition` (provided by Multus) in `infrastructure/base/networking-lab` to create a Linux Bridge (e.g., `br-lab`).
*   **Task 3.2:** Apply the definition and ensure it is available for pods to attach to.

---

## Milestone 4: Storage Configuration for VMs
*Goal: Prepare the persistent storage mechanisms required for VM boot disks (ContainerDisks or PVCs).*

*   **Task 4.1:** Verify OpenEBS/SeaweedFS storage classes are ready for use.
*   **Task 4.2:** Decide on the boot method: ContainerDisk (ephemeral, good for VyOS base) vs. PVC (persistent, better for Ubuntu state).
*   **Task 4.3:** If using PVCs, pre-create the DataVolumes using Containerized Data Importer (CDI) if necessary, or rely on standard PVCs with initialization. Note: CDI is highly recommended for importing OS images directly into KubeVirt. *We may need to add CDI deployment as a sub-task here.*

---

## Milestone 5: VyOS VM Provisioning (The Router)
*Goal: Deploy the core router that will manage the lab networks.*

*   **Task 5.1:** Create a KubeVirt `VirtualMachine` manifest for VyOS in `apps/base/networking-lab/vyos`.
*   **Task 5.2:** Configure the VM to have two interfaces:
    *   `eth0`: Default pod network (masquerade/management).
    *   `eth1`: Multus `NetworkAttachmentDefinition` network (the isolated lab network).
*   **Task 5.3:** Deploy via ArgoCD (`apps/overlays/home` or `home-dev`).
*   **Task 5.4:** Verify the VM boots and connect to its console to perform initial configurations.

---

## Milestone 6: Ubuntu Server VM Provisioning (The Client)
*Goal: Deploy a test client behind the VyOS router to validate network flow.*

*   **Task 6.1:** Create a KubeVirt `VirtualMachine` manifest for Ubuntu Server in `apps/base/networking-lab/ubuntu`.
*   **Task 6.2:** Configure the VM to connect **only** to the Multus `NetworkAttachmentDefinition` network (the isolated lab network). It should not have direct access to the pod network.
*   **Task 6.3:** Deploy via ArgoCD.
*   **Task 6.4:** Verify the VM boots.

---

## Milestone 7: Networking Practice & Validation
*Goal: Confirm the lab works as intended by routing traffic from Ubuntu through VyOS.*

*   **Task 7.1:** Access the VyOS console and configure DHCP/Static IP for `eth1`.
*   **Task 7.2:** Access the Ubuntu console and configure its network interface to point to VyOS as the gateway.
*   **Task 7.3:** Validate connectivity (e.g., ping from Ubuntu -> VyOS -> Internet).

---

## Future Enhancements
*   Add a secondary "DMZ" NetworkAttachmentDefinition.
*   Deploy additional VMs to practice BGP, OSPF, or VLAN tagging.
