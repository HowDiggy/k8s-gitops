# Langfuse & LiteLLM Gateway Architecture and Operational Runbook

This document provides architectural specifications, dependency graphs, bootstrap procedures, and diagnostic runbooks for the AI proxy and LLM observability stack deployed on the **K3s Homelab Cluster** (`home`), integrated with local GPU inference on the **NVIDIA DGX Spark** workstation (`happy`).

---

## 1. Architectural Overview & Mental Model

The AI inference infrastructure couples **LiteLLM Gateway** (a high-performance unified LLM reverse proxy and router) with **Langfuse** (an enterprise-grade OpenTelemetry-native LLM engineering and observability platform). Local high-throughput inference runs outside the Kubernetes cluster on an **NVIDIA DGX Spark** workstation (`happy`, `192.168.1.42:8000`) hosting vLLM with the 120B parameter `nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4` model.

```mermaid
flowchart TD
    subgraph ClientTier["Client / Application Layer"]
        Apps["Client Applications / Agents / SDKs"]
    end

    subgraph IngressTier["Ingress & Gateway (Cilium L7 Envoy)"]
        VIP["Cilium Floating VIP: 192.168.1.60"]
        HR_LiteLLM["HTTPRoute: litellm.homelab.local"]
        HR_Langfuse["HTTPRoute: langfuse.homelab.local"]
        VIP --> HR_LiteLLM
        VIP --> HR_Langfuse
    end

    subgraph LiteLLMTier["Namespace: litellm"]
        LiteLLM["LiteLLM Proxy (ghcr.io/berriai/litellm-database:v1.99.0)"]
        LiteLLM_DB["PostgreSQL (CNPG Cluster: litellm-db)"]
        LiteLLM_Cache["Valkey Cache (valkey/valkey:8-alpine)"]
        SVC_DGX["Service: vllm-dgx (type: ExternalName)"]

        LiteLLM -->|Virtual Keys / Spend| LiteLLM_DB
        LiteLLM -->|Rate Limiting / LRU Cache| LiteLLM_Cache
        LiteLLM -->|External Inference Routing| SVC_DGX
    end

    subgraph WorkstationTier["Local Workstation (192.168.1.42)"]
        DGX["NVIDIA DGX Spark (happy:8000)"]
        vLLM["vLLM: Nemotron-3-Super 120B FP4"]
        SVC_DGX -.->|CoreDNS CNAME happy| DGX
        DGX --> vLLM
    end

    subgraph LangfuseTier["Namespace: langfuse"]
        LangfuseWeb["Langfuse Web (ghcr.io/langfuse/langfuse:4.30.0)"]
        LangfuseWorker["Langfuse Worker (ghcr.io/langfuse/langfuse-worker:4.30.0)"]
        Langfuse_PG["PostgreSQL (CNPG Cluster: langfuse-db)"]
        Langfuse_CH["ClickHouse OLAP (clickhouse-server:26.8-alpine)"]
        Langfuse_Cache["Valkey BullMQ Queue (valkey/valkey:8-alpine)"]
        
        LangfuseWeb -->|OLTP Metadata| Langfuse_PG
        LangfuseWeb -->|Traces & Analytics Queries| Langfuse_CH
        LangfuseWeb -->|Async Job Dispatch| Langfuse_Cache
        LangfuseWorker -->|BullMQ Consumer| Langfuse_Cache
        LangfuseWorker -->|Batch Flush / Dual-Write Merge| Langfuse_CH
        LangfuseWorker -->|Metadata Updates| Langfuse_PG
    end

    subgraph StorageTier["Namespace: seaweedfs"]
        SeaweedFS["SeaweedFS S3 Gateway (Port 8333)"]
        SeaweedFS_Vol["Volume Server (100Gi PVC, maxVolumes: 100)"]
        SeaweedFS --> SeaweedFS_Vol
        LangfuseWeb -->|Raw Ingestion Payloads / Media| SeaweedFS
        LangfuseWorker -->|Batch Exports / Large Blobs| SeaweedFS
    end

    subgraph MonitoringTier["Namespace: monitoring"]
        Prometheus["Prometheus (kube-prometheus-stack)"]
        Prometheus -->|Scrapes /metrics with Bearer Token| LiteLLM
    end

    Apps --> VIP
    HR_LiteLLM --> LiteLLM
    HR_Langfuse --> LangfuseWeb
    LiteLLM -.->|Async Telemetry Callbacks (Dual-Write Bridge)| LangfuseWeb
```

### Component Breakdown
1. **LiteLLM Gateway (`litellm`):**
   - Single unified endpoint compatible with OpenAI schema (`/v1/chat/completions`, `/v1/embeddings`).
   - Manages model fallbacks, virtual API keys, team budgets, and token-bucket rate limiting backed by Valkey.
   - Routes inference requests to external workstation vLLM and cloud providers (OpenAI, Anthropic).
   - Asynchronously streams trace telemetry and cost calculations to Langfuse.
2. **Langfuse (`langfuse`):**
   - **Web Container:** Next.js application hosting the administrative UI, ingestion endpoints, project settings, and real-time trace exploration.
   - **Worker Container:** Node.js background engine executing BullMQ worker queues, ClickHouse batch maintenance, and dual-write partition merging.
   - **ClickHouse Server (26.8 LTS):** High-throughput columnar OLAP engine storing trace events (`events_core`, `events_full`, `traces`, `observations`).
   - **CloudNativePG (`langfuse-db`):** PostgreSQL relational database managing organizations, projects, user identities, and cryptographic API keys.
   - **SeaweedFS S3:** S3-compatible object store storing raw event blobs and payloads exceeding transactional limits.

---

## 2. Ingress & Networking Specifications

| Service | Subdomain | Internal Cluster Service | Exposed Ports | Ingress Controller |
| :--- | :--- | :--- | :--- | :--- |
| **LiteLLM** | `litellm.homelab.local` | `litellm.litellm.svc:4000` | `80` (Redirect), `443` (TLS) | Cilium Gateway API |
| **Langfuse** | `langfuse.homelab.local` | `langfuse-web.langfuse.svc:3000` | `80` (Redirect), `443` (TLS) | Cilium Gateway API |
| **vLLM (DGX)** | `vllm-dgx.litellm.svc` | `vllm-dgx.litellm.svc:8000` | `8000` (HTTP) | Kubernetes `ExternalName` |
| **SeaweedFS S3** | In-Cluster Only | `seaweedfs-s3.seaweedfs.svc:8333` | `8333` (S3 API) | Internal CoreDNS |

### macOS Unicast DNS Resolution (.local Bypass)
Because `.local` is reserved for Multicast DNS (RFC 6762), macOS queries mDNS responder by default and fails to resolve unicast LAN DNS. To route `*.homelab.local` to the cluster Gateway VIP (`192.168.1.60`) via local router DNS (`192.168.1.1`), maintain `/etc/resolver/homelab.local`:

```bash
sudo mkdir -p /etc/resolver
sudo tee /etc/resolver/homelab.local << 'EOF'
nameserver 192.168.1.1
EOF
```

---

## 3. Authentication & Doppler Secrets Mapping

All sensitive credentials and database connection strings are stored in **Doppler** under project **`k8s-eso`** (environment **`dev`**) and synchronized to Kubernetes via the **External Secrets Operator** (`ClusterSecretStore/doppler-backend`).

### Doppler Secrets Vault Schema

| Doppler Key | Destination Kubernetes Secret | Target Component / Description |
| :--- | :--- | :--- |
| `LITELLM_MASTER_KEY` | `litellm-secrets` | LiteLLM Admin API Key & UI Admin Password (`sk-homelab-...`) |
| `LITELLM_DB_PASSWORD` | `litellm-secrets` | CloudNativePG `litellm-db` app user password |
| `LANGFUSE_PUBLIC_KEY` | `litellm-secrets` | Langfuse project public API key (`pk-lf-...`) |
| `LANGFUSE_SECRET_KEY` | `litellm-secrets` | Langfuse project secret API key (`sk-lf-...`) |
| `LANGFUSE_DB_PASSWORD` | `langfuse-secrets` | CloudNativePG `langfuse-db` app user password |
| `LANGFUSE_CLICKHOUSE_PASSWORD` | `langfuse-secrets` | ClickHouse user `default` password |
| `LANGFUSE_NEXTAUTH_SECRET` | `langfuse-secrets` | NextAuth encryption secret for browser sessions |
| `LANGFUSE_SALT` | `langfuse-secrets` | Cryptographic salt for API key hashing |
| `LANGFUSE_ENCRYPTION_KEY` | `langfuse-secrets` | 64-character hex key for encrypting provider keys at rest |
| `SEAWEEDFS_S3_ACCESS_KEY` | `langfuse-secrets` | SeaweedFS S3 IAM access key |
| `SEAWEEDFS_S3_SECRET_KEY` | `langfuse-secrets` | SeaweedFS S3 IAM secret key |

### LiteLLM UI Authentication
To log into the LiteLLM Admin Panel (`https://litellm.homelab.local/ui`):
* **Username:** `admin`
* **Password:** Value of `LITELLM_MASTER_KEY` (`sk-homelab-7a3403442aa305002d68163692570ae6`).
* *Custom Credentials (Optional):* Setting `UI_USERNAME` and `UI_PASSWORD` in Doppler allows logging in with human-friendly credentials rather than the master API key.

---

## 4. Local Workstation vLLM Inference (DGX Spark)

### 4.1 Workstation Setup (`happy`, 192.168.1.42)
The DGX Spark workstation runs Docker Compose hosting `vllm/vllm-openai` at port `8000`:
* **Path:** `/home/paulo/infrastructure/local-llm/nemotron/moe-120`
* **Command:** `docker compose up -d`
* **Model:** `nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4`

### 4.2 Kubernetes Service Abstraction (`type: ExternalName`)
To avoid kubelet/containerd overhead on the workstation and prevent scheduling locks, the external workstation is exposed in-cluster using a native `spec.type: ExternalName` Service in [`apps/base/litellm/03b-vllm-dgx-service.yaml`](file:///Users/paulojauregui/projects/k8s-gitops/apps/base/litellm/03b-vllm-dgx-service.yaml):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: vllm-dgx
  namespace: litellm
  labels:
    app.kubernetes.io/name: vllm-dgx
    app.kubernetes.io/component: inference
spec:
  type: ExternalName
  externalName: happy
  ports:
    - name: http
      port: 8000
      targetPort: 8000
      protocol: TCP
```
*Why ExternalName?* CoreDNS translates queries for `vllm-dgx.litellm.svc.cluster.local` to CNAME `happy` (which resolves to `192.168.1.42`), requiring no manual `EndpointSlice` manifests and preventing ArgoCD resource exclusion warnings.

### 4.3 Model Aliasing in LiteLLM Proxy
Configured in [`apps/base/litellm/04-configmap.yaml`](file:///Users/paulojauregui/projects/k8s-gitops/apps/base/litellm/04-configmap.yaml):
```yaml
model_list:
  - model_name: nemotron-3-super
    litellm_params:
      model: openai/nemotron-3-super
      api_base: http://vllm-dgx:8000/v1
      api_key: "none"
  - model_name: local-llm
    litellm_params:
      model: openai/nemotron-3-super
      api_base: http://vllm-dgx:8000/v1
      api_key: "none"
```

---

## 5. Storage & Telemetry Architecture

### 5.1 SeaweedFS S3 Sizing & Volume Configuration
In Langfuse v4, raw ingestion event batches and media assets are written directly to S3.
* **Storage Backing:** 100Gi OpenEBS LocalPV (`openebs-hostpath`).
* **Volume Limits:** SeaweedFS defaults to `maxVolumes: 7` (7 volumes $\times$ 1GB = 7GB limit), which causes volume allocation failure (`free: 0`) under sustained writes.
* **Configuration:** In [`infrastructure/overlays/home/seaweedfs-values.yaml`](file:///Users/paulojauregui/projects/k8s-gitops/infrastructure/overlays/home/seaweedfs-values.yaml), `maxVolumes: 100` is explicitly set to unlock the full 100Gi volume pool:
  ```yaml
  volume:
    dataDirs:
      - name: data1
        type: "persistentVolumeClaim"
        size: "100Gi"
        storageClass: "openebs-hostpath"
        maxVolumes: 100
  ```

### 5.2 Langfuse v4 Dual-Write Migration Bridge
* **The Compatibility Gap:** Langfuse v4 defaults to `events_only` write mode for native OpenTelemetry ingestion. LiteLLM's bundled Langfuse client dispatches legacy JSON batch payloads to `/api/public/ingestion`.
* **The Bridge:** Setting `LANGFUSE_MIGRATION_V4_WRITE_MODE: "dual"` on both `langfuse-web` and `langfuse-worker` instructs Langfuse to accept legacy `/api/public/ingestion` calls (returning HTTP `207 Multi-Status`), stage observations into `observations_batch_staging`, and denormalize them asynchronously into `events_full` and `events_core`.

### 5.3 Caching Tier (Valkey vs. Redis)
LiteLLM and Langfuse are backed by **Valkey 8.0** instances. Because Valkey implements 100% protocol compatibility with the **RESP (REdis Serialization Protocol)** on TCP port `6379`, LiteLLM’s `type: "redis"` configuration operates seamlessly with the standard `redis-py` driver.
* In [`apps/base/litellm/04-configmap.yaml`](file:///Users/paulojauregui/projects/k8s-gitops/apps/base/litellm/04-configmap.yaml), caching is defined using:
  ```yaml
  litellm_settings:
    cache: true
    cache_params:
      type: "redis"
      host: "litellm-valkey"
      port: 6379
  ```

---

## 6. Diagnostic Runbooks & Failure Mode Matrix

### 6.1 End-to-End Verification Procedures

#### A. Test Model Inference via LiteLLM Gateway
```bash
export LITELLM_KEY=$(doppler secrets get LITELLM_MASTER_KEY --project k8s-eso --config dev --plain)

curl -k -s https://litellm.homelab.local/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local-llm",
    "messages": [{"role": "user", "content": "Explain PagedAttention in one sentence."}],
    "max_tokens": 50,
    "metadata": {"trace_user_id": "paulo", "generation_name": "diagnostic-test"}
  }' | jq .
```

#### B. Verify Ingestion in ClickHouse
```bash
# Verify record count across all ClickHouse tables
kubectl exec -n langfuse langfuse-clickhouse-0 -- clickhouse-client --query "
SELECT table, sum(rows) FROM system.parts WHERE database = 'default' AND active GROUP BY table
"

# Inspect latest recorded generation observations
kubectl exec -n langfuse langfuse-clickhouse-0 -- clickhouse-client --query "
SELECT id, name, provided_model_name, usage_details, input, output FROM default.observations FORMAT Vertical
"
```

#### C. Verify SeaweedFS S3 Object Storage Health
```bash
# Check volume server capacity and free volume slots
kubectl exec -i -n seaweedfs seaweedfs-master-0 -- weed shell -master=localhost:9333 << 'EOF'
volume.list
EOF
```

#### D. Scrape Prometheus Metrics from LiteLLM
```bash
kubectl exec -n litellm deploy/litellm -- curl -s http://localhost:4000/metrics | grep -E 'litellm_requests_metric|litellm_spend_metric'
```

---

### 6.2 Failure Mode Reference & Resolution Matrix

| Symptom / Error | Root Cause | Resolution |
| :--- | :--- | :--- |
| `ExcludedResourceWarning: Resource discovery.k8s.io/EndpointSlice ... is excluded in the settings` | ArgoCD `argocd-cm` excludes EndpointSlice resources by default to avoid tracking dynamic pod churn. | Refactored [`apps/base/litellm/03b-vllm-dgx-service.yaml`](file:///Users/paulojauregui/projects/k8s-gitops/apps/base/litellm/03b-vllm-dgx-service.yaml) to use `spec.type: ExternalName` pointing to hostname `happy`. |
| `AttributeError: 'dict' object has no attribute 'cache'` | Defining `cache:` as a mapping in `litellm_settings` assigned a Python `dict` directly to `litellm.cache`. | Configured `cache: true` with a separate `cache_params:` block in [`apps/base/litellm/04-configmap.yaml`](file:///Users/paulojauregui/projects/k8s-gitops/apps/base/litellm/04-configmap.yaml). |
| `Rejected 2 event(s) from legacy /api/public/ingestion ... runs in events_only mode` | Langfuse v4 rejects legacy batch schemas by default unless dual-write migration mode is active. | Set `LANGFUSE_MIGRATION_V4_WRITE_MODE: "dual"` on `langfuse-web` and `langfuse-worker` deployments. |
| `S3ServiceException [InternalError]: ... assign volume: all filers failed ... DeadlineExceeded` | SeaweedFS defaulted to `maxVolumes: 7` on a 100Gi volume, exhausting volume slots (`free: 0`). | Added `maxVolumes: 100` under `volume.dataDirs` in [`infrastructure/overlays/home/seaweedfs-values.yaml`](file:///Users/paulojauregui/projects/k8s-gitops/infrastructure/overlays/home/seaweedfs-values.yaml). |
| LiteLLM UI login returns `Invalid credentials used to access UI. Check 'UI_USERNAME', 'UI_PASSWORD'` | Username field left blank; LiteLLM UI expects Username `admin` and Password equal to `LITELLM_MASTER_KEY`. | Log in with Username `admin` and Password set to the Doppler `LITELLM_MASTER_KEY` value (`sk-homelab-...`). |
