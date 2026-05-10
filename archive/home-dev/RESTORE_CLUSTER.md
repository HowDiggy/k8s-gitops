# Restoring the `home-dev` Talos Cluster

This directory contains the archived GitOps state for the `home-dev` local Talos cluster. 

If you decide to power on the local hardware and restore this environment, follow these steps to re-integrate it with the Hub (OCI) ArgoCD instance.

## 1. Prerequisites
- Power on the 3 local Talos nodes.
- Ensure Talos OS is healthy and etcd has quorum (e.g., via `talosctl health`).
- Verify that your local network/router correctly assigns them their static IPs.

## 2. Un-Archiving the Manifests
Move the configurations back to their active locations in the Git repository:

```bash
# From the root of the repository:
git mv archive/home-dev/clusters/home-dev clusters/
git mv archive/home-dev/infrastructure/home-dev infrastructure/overlays/
git mv archive/home-dev/apps/development apps/overlays/
```

## 3. Re-establishing the Cloudflare Tunnel
The `home-dev` cluster requires a Cloudflare tunnel to securely communicate outbound to the OCI Hub cluster and internet without exposing local router ports. 
- Ensure the `cloudflare-app.yaml` (now in `clusters/home-dev/`) is deployed.
- Verify the Cloudflare tunnel secret (`new-sealed-cloudflare-token.yaml` or similar in `bootstrap/`) is applied to the cluster.

## 4. GitOps Synchronization
1. Commit the restored file paths and push to GitHub:
   ```bash
   git commit -m "chore: restore home-dev cluster configurations"
   git push origin main
   ```
2. Apply the root applications directly to the Hub cluster (OCI) so ArgoCD begins managing them again:
   ```bash
   kubectl config use-context <oci-hub-context>
   kubectl apply -f clusters/home-dev/infra-root.yaml
   kubectl apply -f clusters/home-dev/apps-root.yaml
   ```
3. ArgoCD will now detect the re-activated applications. Open the ArgoCD UI and ensure the `home-dev-infra-root` and `home-dev-apps-root` applications are syncing successfully to the target cluster.
