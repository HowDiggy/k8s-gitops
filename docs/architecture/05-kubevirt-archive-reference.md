# KubeVirt Networking Lab Reference

This document serves as a historical reference for the KubeVirt-based networking lab infrastructure that was deployed on the Talos Kubernetes cluster prior to its decommissioning. It captures the necessary components, configurations, and fixes required to achieve a stable state.

## 1. Infrastructure Components

### KubeVirt Operator and API
*   **Location:** `infrastructure/base/kubevirt`
*   **Deployment:** Managed by ArgoCD via the `home-dev-kubevirt` Application.
*   **Components:** `virt-operator`, `virt-api`, `virt-controller`, `virt-handler`.

### ArgoCD Custom Health Checks
To prevent ArgoCD from endlessly polling the `VirtualMachineInstance` and `virt-launcher` pods (which use `restartPolicy: Never`), custom Lua health checks were injected into the `argocd-cm` ConfigMap (`infrastructure/base/argocd/argocd-cm.yaml`).

```yaml
  resource.customizations.health.Pod: |
    # ... (Custom Lua script to mark KubeVirt pods as Healthy when Running)
  resource.customizations.health.kubevirt.io_VirtualMachine: |
    # ... (Custom Lua script to map printableStatus 'Running' to Healthy)
  resource.customizations.health.kubevirt.io_VirtualMachineInstance: |
    # ... (Custom Lua script to map phase 'Running' to Healthy)
```

## 2. Workload Definitions (The VMs)

*   **Location:** `apps/base/networking-lab`
*   **Deployment:** Managed by ArgoCD via the `networking-lab-workloads` Application.

The lab consisted of 4 VirtualMachines (2 Routers, 2 Ubuntu Clients) across two simulated sites.

### Key Configurations:
*   **Storage (`ephemeral-storage`):** Crucial fix applied. `containerDisks` default to 50Mi requests, which causes KubeVirt to continuously log "No disk capacity" errors during expansion checks. All VMs were updated to explicitly request `40Gi` of `ephemeral-storage`.
*   **Images:** Used `quay.io/containerdisks/ubuntu:24.04`.
*   **Networking:** Attached to Multus Bridge networks (`br-lab`, `br-lab-site2`).
*   **Provisioning:** Used `cloudInitNoCloud` to inject default passwords and initial IP routing configurations.

### Example VM Manifest (Ubuntu Client)
```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  labels:
    kubevirt.io/vm: ubuntu-vm
  name: ubuntu-client
  namespace: networking-lab
spec:
  runStrategy: Always
  template:
    spec:
      architecture: amd64
      domain:
        resources:
          requests:
            memory: 1024M
            cpu: "1"
            ephemeral-storage: "40Gi" # CRITICAL FIX
        devices:
          disks:
            - disk:
                bus: virtio
              name: containerdisk
            - disk:
                bus: virtio
              name: cloudinitdisk
          interfaces:
            - masquerade: {}
              name: default
            - bridge: {}
              name: br-lab-iface
      networks:
        - name: default
          pod: {}
        - name: br-lab-iface
          multus:
            networkName: br-lab
      volumes:
        - containerDisk:
            image: quay.io/containerdisks/ubuntu:24.04
          name: containerdisk
        - cloudInitNoCloud:
            userData: |
              #cloud-config
              password: password
              chpasswd: { expire: False }
          name: cloudinitdisk
```

## 3. Known Behaviors & Thermal Impact
*   **Spooling:** Deploying multiple VMs simultaneously causes significant initial CPU/IO load.
*   **ArgoCD Polling:** Without the custom Lua health checks, ArgoCD will continuously poll the API server, keeping CPU usage artificially high and causing sustained fan noise.
*   **Disk Expansion Logs:** "No disk capacity" in `virt-launcher` logs is a benign warning for `containerDisks` but was initially misidentified as a failure.