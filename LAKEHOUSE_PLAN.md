# Detailed Implementation Plan: AI-Enriched Lakehouse

This document outlines the step-by-step technical milestones required to transform the Talos Spoke cluster into an AI-enriched Data Engineering platform. The strategy emphasizes a strong foundation in Apache Spark (PySpark) to directly mimic a Databricks environment, allowing for immediate skills transfer to enterprise work.

## Architecture Overview
*   **Storage (Data Lake):** SeaweedFS (S3-compatible, high-throughput, small-file optimized).
*   **Compute Engine (Batch & Micro-batch):** Apache Spark (via Kubernetes Operator).
*   **Message Broker (Streaming):** Redpanda (Kafka-compatible, JVM-free).
*   **AI Inference (UDF):** vLLM (running locally on DGX Spark) called via Python `asyncio`.
*   **Data Format (Lakehouse):** Delta Lake.
*   **Observability & Tracking:** MLflow (experiment tracking) and existing Prometheus/Grafana stack.

---

## Milestone 1: The Data Lake Foundation (SeaweedFS)
**Goal:** Establish a high-performance, S3-compatible object storage layer to serve as the foundation for the Lakehouse.

### Technical Steps:
1.  **Preparation:**
    *   Create a namespace: `seaweedfs`.
    *   Generate secure S3 credentials (Access Key / Secret Key) and store them in the Doppler `k8s-eso` project.
    *   Create an `ExternalSecret` manifest to synchronize these credentials into the `seaweedfs` namespace.
2.  **Deployment (Helm via Kustomize):**
    *   Add the SeaweedFS Helm repository.
    *   Create Kustomize manifests in `infrastructure/base/seaweedfs` leveraging the Helm Chart integration.
    *   Configure the chart to deploy the Master, Volume, and Filer components.
    *   Enable the S3 API Gateway component and configure it to use the credentials injected via ESO.
3.  **Validation:**
    *   Port-forward the S3 API service.
    *   Use the `aws s3` CLI (configured with the custom endpoint) to create three buckets: `mlflow-artifacts`, `bronze-logs`, and `silver-enriched`.

---

## Milestone 2: AI Experiment Tracking (MLflow)
**Goal:** Deploy MLflow to track AI models and metrics, utilizing the existing Postgres cluster for metadata and the new SeaweedFS for artifacts.

### Technical Steps:
1.  **Database Provisioning:**
    *   Access the existing CloudNativePG (CNPG) cluster and create a dedicated `mlflow` database and user.
2.  **Secret Management:**
    *   Store the Postgres and SeaweedFS S3 credentials in Doppler under the MLflow context.
    *   Create an `ExternalSecret` in the `mlflow` namespace.
3.  **Deployment & Validation:**
    *   Deploy MLflow via ArgoCD pointing artifact storage to SeaweedFS.
    *   Run a simple Python script to log a dummy parameter and artifact to verify connectivity.

---

## Milestone 2.5: The Agentic Foundation (Vector Database)
**Goal:** Deploy a centralized, always-on vector database (Qdrant) to serve as the shared "Enterprise Memory" for multiple LLM agents and RAG pipelines.

### Technical Steps:
1.  **Deployment via Kustomize:**
    *   Add the official Qdrant Helm repository.
    *   Create a `qdrant` namespace and generate base Kustomize manifests (`infrastructure/base/qdrant`).
    *   *Why Qdrant:* Written entirely in Rust, Qdrant is exceptionally fast and memory-safe. It implements an efficient HNSW (Hierarchical Navigable Small World) graph and handles concurrent requests smoothly, making it ideal for the resource constraints of an edge/home lab cluster.
2.  **Storage and Resiliency:**
    *   Configure the Helm chart to use local storage (OpenEBS) for maximum read/write performance for high-dimensional vectors.
3.  **Security Integration:**
    *   Generate a secure API Key for cluster access.
    *   Store the API Key in Doppler and sync it to the `qdrant` namespace via the External Secrets Operator.
4.  **Validation:**
    *   Port-forward the Qdrant REST/gRPC service.
    *   Initialize an empty collection via `curl` or the Python client to confirm successful deployment and authentication.

---

## Milestone 3: The Spark Foundation (Batch AI Lakehouse)
**Goal:** Deploy the Spark Kubernetes Operator and write a PySpark batch job to master the fundamentals of distributed processing and Pandas UDFs without the complexity of streaming.

### Technical Steps:
1.  **Operator Deployment:**
    *   Install the official Spark Kubernetes Operator via Helm/Kustomize in the `spark-operator` namespace.
2.  **Base Image Preparation:**
    *   Build a custom Docker image extending the official Spark Python image.
    *   Install necessary Python dependencies: `pyspark`, `aioboto3` (or `aiohttp` for vLLM), `pandas`, `pyarrow`, and `delta-spark`.
3.  **The Vectorized AI UDF (PySpark):**
    *   Develop a PySpark Pandas UDF (`@pandas_udf`).
    *   Inside the UDF, implement `asyncio` to make concurrent HTTP requests to the local vLLM endpoint on the DGX Spark.
4.  **Batch Job Execution:**
    *   Upload a static Parquet file containing dummy log paths to SeaweedFS.
    *   Create a `SparkApplication` CR that reads the Parquet file, applies the AI UDF, and writes the enriched dataset back to SeaweedFS using the Delta Lake format (`s3a://silver-enriched/batch-analysis/`).
5.  **Validation:**
    *   Query the Delta table in SeaweedFS to verify the AI-inferred columns are present and accurate.

---

## Milestone 4: The Streaming Backbone (Redpanda)
**Goal:** Deploy a Kafka-compatible message broker to simulate a real-time data ingestion pipeline.

### Technical Steps:
1.  **Operator Deployment:**
    *   Install the Redpanda Operator via Helm/Kustomize.
2.  **Cluster Provisioning:**
    *   Create a `Redpanda` Custom Resource (CR) and configure storage.
3.  **Topic Creation & Producer:**
    *   Use the `rpk` CLI to create a topic named `raw-system-paths`.
    *   Containerize a Python script that continuously generates synthetic JSON logs and deploy it as a Kubernetes `Deployment`.

---

## Milestone 5: Structured Streaming Upgrade
**Goal:** Upgrade the PySpark pipeline from a static batch job to a Spark Structured Streaming job.

### Technical Steps:
1.  **Refactor the PySpark Job:**
    *   Update the `SparkApplication` source code to use `spark.readStream` subscribing to the Redpanda Kafka topic.
    *   Ensure the streaming job retains the same Vectorized AI UDF used in Milestone 3.
2.  **Sink to Delta Lake:**
    *   Configure the streaming sink to append the AI-enriched data continuously to the SeaweedFS Delta Table with a defined checkpoint location.
3.  **Validation:**
    *   Launch a local PySpark shell and continuously query the Delta table (`spark.read.format("delta").load(...)`) to verify that new logs are being enriched and written in near real-time.

---

## 4. Definition of Done
The primary project phase is complete when a synthetic log generated by the Producer is automatically consumed by Spark Structured Streaming, enriched by vLLM via an async UDF, and continuously appended to a Delta Lake table in SeaweedFS.