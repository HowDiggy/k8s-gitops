# Roadmap: Hybrid Cloud API Bridge (Cloudflare Tunnel)

## 1. Project Context Summary
- **The Vision:** A Hub-and-Spoke GitOps model. OCI is the Management Hub (ArgoCD, Monitoring); Talos (Local Lab) is the Workload Spoke.
- **OCI Cluster (Hub):** `context-cxgwihujioa`. 2 managed ARM nodes.
- **Talos Cluster (Spoke):** `dalia`. 3-node HA cluster. VIP: `192.168.1.50:6443`.
- **Infrastructure State:** All legacy workloads (SignConnect) have been cleared. Doppler is established for cross-cluster secret syncing. Tailscale approach was decommissioned and cleaned.

## 2. Implementation Roadmap

### Phase 1: Cloudflare Zero Trust Configuration (Manual)
1. **Create Tunnel:** In the Cloudflare Zero Trust dashboard, create a new Tunnel named `talos-bridge`.
2. **Obtain Token:** Save the Tunnel Token.
3. **Configure Hostname:** Map `talos-api.paulojauregui.com` to internal service `https://192.168.1.50:6443`.
4. **Security Policy:** Create an Access Application for the FQDN.
    - **Policy 1:** Allow the OCI Public IP (find via `curl ifconfig.me` from an OCI pod).
    - **Policy 2:** Allow your own email/SSO for emergency access.

### Phase 2: Talos Deployment (Automatic)
1. **Secret Storage:** Add the `CLOUDFLARE_TUNNEL_TOKEN` to the Doppler `prd` config.
2. **Manifest Creation:**
    - Create `infrastructure/base/cloudflare-talos` containing a `cloudflared` Deployment.
    - Use `ExternalSecret` to pull the token into the `cloudflare` namespace on Talos.
3. **GitOps Sync:** Add the new resource to the Talos application path and sync via OCI ArgoCD.

### Phase 3: Final Integration
1. **Verification:** Confirm `curl -k https://talos-api.paulojauregui.com/version` works from an OCI pod.
2. **Registration:** Register the cluster in ArgoCD:
    ```bash
    argocd cluster add dalia --name talos-lab --server talos-api.paulojauregui.com:443 --insecure
    ```

---

## 3. Handover Prompt for New Conversation

Copy and paste this prompt into a new Gemini CLI session to resume immediately:

> "I am resuming the Hybrid Cloud migration project. We have successfully cleaned the environment after a failed Tailscale experiment. 
> 
> **Current State:**
> - OCI (Hub): `context-cxgwihujioa`
> - Talos (Spoke): `dalia` (VIP 192.168.1.50)
> - Goal: Bridge Talos API to OCI ArgoCD using a Cloudflare Tunnel.
> - Secrets: Managed via Doppler.
> 
> **Instructions:**
> 1. Please read the existing `ARCHITECTURE.md` and `ROADMAP.md` in the root.
> 2. Help me implement the Cloudflare Tunnel bridge according to the roadmap in `tailscale-cleanup.md`.
> 3. Start by helping me verify the OCI public IP for the Cloudflare Access policy, then draft the `cloudflared` deployment for Talos."
