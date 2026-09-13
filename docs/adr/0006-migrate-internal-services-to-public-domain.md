# 6. Migrate Internal Services to Public Domain

Date: 2026-09-12

## Status

Accepted

## Context

Historically, all internal homelab services (ArgoCD, Mealie, Calibre-Web, Langfuse, LiteLLM) were hosted on the `.homelab.local` domain. This domain was strictly internal, and TLS termination was handled via a cert-manager `ClusterIssuer` generating self-signed certificates.

While this setup was secure and fully encrypted, modern browsers (Safari, Chrome) increasingly enforce strict certificate trust chains, leading to frequent "Your connection is not private" or "Safari Can't Find the Server" errors unless the self-signed root CA was manually injected into the trust store of every client device. This friction became a blocker for seamless usability on personal laptops and mobile devices.

Additionally, we already owned the `paulojauregui.com` domain and had configured a Let's Encrypt DNS-01 wildcard certificate (`*.paulojauregui.com`) for externally facing services (like Immich).

## Decision

We have decided to migrate all internal `.local` applications to use subdomains on the internet-routable domain `.paulojauregui.com` (e.g., `argocd-home.paulojauregui.com`, `mealie.paulojauregui.com`). 

To preserve the internal-only nature of these services, we will use a **Split-Horizon DNS** architecture:
1. The external DNS (e.g., Cloudflare) will not have records pointing to these internal apps.
2. The internal home router/gateway (UniFi Dream Machine at `192.168.1.1`) is configured with a wildcard DNS record (`*.paulojauregui.com`) pointing to the internal cluster Gateway API VIP (`192.168.1.60`).
3. The cluster Gateway API's `https-public` listener will terminate TLS using the valid Let's Encrypt wildcard certificate.

## Consequences

* **Positive**: Browser trust warnings are entirely eliminated across all client devices without requiring manual CA trust store configuration.
* **Positive**: Certificate lifecycle management is centralized and automated via ACME DNS-01 challenges.
* **Neutral**: The services remain 100% internal and inaccessible from the public internet, despite using a `.com` domain, because the DNS resolution pointing to the private `192.168.x.x` subnet only exists on the local router.
* **Negative**: If the local router's DNS server fails, clients will fallback to external DNS resolvers (like 1.1.1.1) which will not know how to route `argocd-home.paulojauregui.com`.
* **Mitigation**: We have retained the `https-local` listener on the Gateway as a deprecated fallback, allowing emergency access via `mDNS` and `.local` in the event of a catastrophic DNS routing failure.
