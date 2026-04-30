# Spark Operator Webhook & Cert-Manager Integration

## The Problem: Helm Hooks vs. Kustomize
When deploying the official `spark-operator` Helm chart via Kustomize (`helmCharts` in `kustomization.yaml`), the webhook pod often falls into a `CrashLoopBackOff` because it cannot find its TLS certificates (`spark-operator-webhook-certs` secret).

The Spark Operator chart has a built-in mechanism to generate self-signed certificates without external dependencies. However, this mechanism relies on **Helm Hooks** (temporary Jobs that run before installation). Kustomize, by design, **strips out all Helm Hooks** during its rendering process. Therefore, the built-in certificate generator silently fails to run.

## The Solution: Local Cert-Manager
Because we are building an Enterprise-grade platform, the correct architectural move is to deploy `cert-manager` locally to handle webhook certificates.

### Required Steps
1.  **Deploy Cert-Manager Locally:** Since the OCI Hub's `cert-manager` cannot reach across the network to inject secrets into the local Spoke cluster, a dedicated `cert-manager` instance must be deployed to the Spoke.
2.  **Provide a ClusterIssuer:** A `selfSigned` `ClusterIssuer` must be deployed to the local cluster so `cert-manager` knows how to fulfill the certificate requests.
3.  **Configure Spark Operator Values:**
    *   Disable the built-in upgrade hook: `hook.upgradeCrd: false`
    *   Enable webhook and cert-manager integration.
    *   Explicitly point the `issuerRef` to your `ClusterIssuer`.

```yaml
# spark-operator values.yaml snippet
webhook:
  enable: true

certManager:
  enable: true
  issuerRef:
    name: self-signed-issuer
    kind: ClusterIssuer
    group: cert-manager.io

hook:
  upgradeCrd: false
```
