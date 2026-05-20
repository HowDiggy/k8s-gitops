# Next Session Plan: Azure AKS Spot Integration & Azure DevOps

## 1. Current State of the Workspace
We have successfully performed a strategic pivot from the OCI "Always Free" tier to an Enterprise-grade Azure Kubernetes Service (AKS) architecture to better align with your career goals. 

**Infrastructure:**
- AKS Cluster (`aks-homelab`) is provisioned in `westus2` with the Free Tier control plane.
- The `systempool` (1x `Standard_D2as_v7`) is online and running core K8s services and ArgoCD.
- The `spotpool` is currently **AWAITING QUOTA APPROVAL**. An automated attempt to create a VMSS-based Spot pool failed due to a 0 vCPU quota limit on the `DASv5/v6/v7` families. A support ticket has been filed for an increase to 10 Spot vCPUs.

**GitOps & Automation:**
- ArgoCD is fully bootstrapped via HTTPS. The `azure-prod-infra-root` and `azure-prod-apps-root` applications are actively syncing.
- Azure Workload Identity and OIDC Federation are fully configured. The External Secrets Operator (ESO) successfully assumes the `id-aks-eso` Managed Identity to pull secrets from Azure Key Vault without static credentials.
- All Kustomize manifests (MongoDB, SeaweedFS, Qdrant) have been patched with `nodeSelectors` and `tolerations` targeting `kubernetes.azure.com/scalesetpriority: spot`.
- **Known Issue (Pending Resolution):** Because the Spot nodes do not exist yet, heavy workload pods (Grafana, Qdrant, SeaweedFS, Mongo) are currently in a `Pending` state. The `cnpg-operator` crash loop was fixed in Git via a `ServerSideApply` patch.

## 2. Immediate Action Items (Start of Next Session)

When you return (after receiving the quota approval email from Azure), follow these steps to resume:

### Phase 1: Provision the Spot Nodes
1. Log into the Azure Portal.
2. Navigate to your `aks-homelab` cluster -> **Node pools**.
3. Delete the current placeholder `spotpoolvmss` (if it still exists and isn't configured for Spot).
4. Click **+ Add node pool**:
   - **Name:** `spotpool`
   - **Mode:** `User`
   - **Enable Azure Spot instances:** `Checked` (Critical!)
   - **Eviction type:** `Capacity` | **Eviction policy:** `Delete`
   - **Node size:** `Standard_D2as_v7` (or whichever family was approved).
   - **Scale method:** `Autoscale` (Min 1, Max 3).
5. Once the pool provisions, run `kubectl get nodes -o wide` to verify Kubelet has labeled them with `scalesetpriority: spot`.

### Phase 2: Verify Pod Scheduling & Health
1. Run `kubectl get pods -A | grep -v 'Running\|Completed'`.
2. Ensure the previously `Pending` pods (Grafana, SeaweedFS, MongoDB) successfully schedule onto the new Spot nodes.
3. Check the `cnpg-operator` in the `cnpg-system` namespace to confirm the ArgoCD `ServerSideApply` patch successfully applied the missing CRDs and resolved the crash loop.

### Phase 3: Milestone 5 (Azure DevOps Pipeline Integration)
Once the cluster is 100% green, we will begin the final milestone. The goal is to build an enterprise-grade CI/CD flow where infrastructure values are managed and validated via Azure DevOps before ArgoCD deploys them.

1. **Set up Azure DevOps:** Create a new project and connect it to your GitHub repository.
2. **Pipeline Creation:** Author an `azure-pipelines.yml` file. This pipeline will:
   - Perform linting on your Helm charts and Kustomize overlays.
   - Run `helm template` or `kustomize build` to validate the YAML structure for different tenants/environments.
3. **Approval Gates (Optional):** Implement environment protection rules so changes to `azure-prod` require manual approval in Azure DevOps before merging.

## 3. Prompt to Resume
Copy and paste the following into the Gemini CLI to pick up exactly where we left off:

> "I am returning to the Azure GitOps migration project. We paused while waiting for an Azure quota increase for Spot vCPUs.
> 
> **Current Status:** The quota has been approved. I have just recreated the `spotpool` node pool in the Azure portal, ensuring the 'Enable Azure Spot instances' box is checked.
> 
> **Next Steps:** Please guide me through verifying that the Spot nodes have joined the cluster with the correct labels, and that our previously `Pending` pods (MongoDB, SeaweedFS, etc.) have successfully scheduled onto them. Once the cluster is green, let's proceed to Milestone 5: Azure DevOps Pipeline Integration."
