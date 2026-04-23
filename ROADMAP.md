# Roadmap: Talos Cluster Stabilization and Improvements

## 1. Project Context Summary
- **Current State:** The Hub-and-Spoke GitOps model has been successfully established. The OCI Cluster (`context-cxgwihujioa`) is actively managing the Talos Cluster (`dalia`) via a secure Cloudflare Zero Trust Tunnel.
- **Goal:** Stabilize the `home-dev` infrastructure on the Talos cluster. Current ArgoCD sync issues include degraded states in `kube-prometheus-stack`, unresolved `SealedSecret` dependencies for Grafana, and the need for high availability in the CloudNativePG (`cnpg`) deployment.

## 2. Implementation Roadmap

### Phase 1: Secret Management Cleanup (Doppler Migration)
**Objective:** Fully remove the legacy Bitnami Sealed Secrets dependency and transition Grafana credentials to the External Secrets Operator (ESO) and Doppler.

1.  **Doppler Configuration:**
    - Create a new secret in the Doppler project/config for the Talos cluster containing the Grafana admin credentials (e.g., `GRAFANA_ADMIN_USER`, `GRAFANA_ADMIN_PASSWORD`).
2.  **Manifest Updates:**
    - Remove the `sealed-secrets` ArgoCD Application from the `home-dev` overlay (`infrastructure/overlays/home-dev/sealed-secrets.yaml` or similar references in `kustomization.yaml`).
    - Delete any existing `SealedSecret` manifests for Grafana (e.g., `grafana-admin-credentials`).
    - Create an `ExternalSecret` manifest for Grafana that pulls the new credentials from Doppler and provisions the standard Kubernetes `Secret` expected by the `kube-prometheus-stack` chart.
3.  **GitOps Sync:** Push the changes and ensure the `home-dev-infra-root` application syncs cleanly without the `sealed-secrets` dependency hanging.

### Phase 2: Kube-Prometheus-Stack Stabilization
**Objective:** Resolve the out-of-sync and degraded states in the `kube-prometheus-stack` deployment.

1.  **Investigation:**
    - Examine the ArgoCD UI or use `kubectl` on the Talos cluster to identify the exact resources failing to sync or start within the monitoring namespace.
    - Check the logs of the Prometheus operator, Grafana, and Alertmanager pods for startup failures.
2.  **Configuration Adjustments:**
    - Modify `infrastructure/overlays/home-dev/kps-values.yaml` (or the equivalent values file) to address any resource limits, storage class issues, or conflicting configurations.
    - Ensure the newly created ExternalSecret for Grafana admin credentials is correctly referenced in the Helm values.
3.  **Validation:** Ensure the entire `kube-prometheus-stack` Application reaches a `Healthy` and `Synced` state in ArgoCD.

### Phase 3: High Availability for CloudNativePG (CNPG)
**Objective:** Upgrade the PostgreSQL deployment to a highly available, multi-node cluster.

1.  **Manifest Updates:**
    - Locate the CNPG `Cluster` definition manifest for the Talos cluster.
    - Update the `instances` count from 1 to a higher number (e.g., 3) to ensure redundancy across the Talos nodes.
    - Configure proper pod anti-affinity rules if necessary to ensure instances run on different physical nodes.
    - Verify that the storage configuration (e.g., `storageClass`) supports the HA setup.
2.  **GitOps Sync & Validation:**
    - Commit and push the changes.
    - Monitor the CNPG operator logs and the cluster status via `kubectl get cluster -n <namespace>` to confirm the new instances spin up and replicate successfully.

### Phase 4: MongoDB Deployment
**Objective:** Deploy a highly available MongoDB cluster in the home lab for learning and development, mirroring enterprise environments.

1.  **Operator Selection:** Research and select a robust Kubernetes operator for MongoDB (e.g., MongoDB Community Kubernetes Operator or Percona Server for MongoDB Operator).
2.  **Manifest Creation:**
    - Create the base manifests in `infrastructure/base/mongodb`.
    - Configure an overlay for `home-dev` with a replica set configuration (e.g., 3 nodes) to ensure high availability.
    - Set up Persistent Volume Claims (PVCs) for data storage and configure appropriate resource requests/limits.
3.  **Secret Management:**
    - Generate MongoDB admin credentials and store them securely in Doppler.
    - Create an `ExternalSecret` manifest to synchronize the credentials to the MongoDB namespace.
4.  **GitOps Sync & Validation:** Deploy via ArgoCD and verify the replica set status and connectivity.

---

## 3. Handover Prompt for New Conversation

Copy and paste this prompt into a new Gemini CLI session to resume immediately:

> "I am resuming the Hybrid Cloud migration project. We have successfully connected the OCI Hub to the Talos Spoke via Cloudflare Tunnels.
> 
> **Current State:**
> - OCI (Hub): `context-cxgwihujioa`
> - Talos (Spoke): `dalia` (VIP 192.168.1.50)
> - ArgoCD on OCI is currently attempting to sync the `home-dev` infrastructure to Talos, but it is encountering issues (e.g., waiting for SealedSecrets, kube-prometheus-stack degradation).
> 
> **Instructions:**
> 1. Please read the `ROADMAP.md` in the root.
> 2. Help me execute Phase 1: Secret Management Cleanup. We need to remove the `sealed-secrets` app, migrate Grafana credentials to Doppler, and configure an `ExternalSecret`."
