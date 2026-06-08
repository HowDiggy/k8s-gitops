# SeaweedFS Implementation Plan (Data Lake Foundation)

This document outlines the technical plan for deploying SeaweedFS to the Talos Kubernetes cluster as a lightweight, high-performance alternative to MinIO, and migrating the existing MLflow application to use it.

## Architecture & Constraints
*   **Deployment Method:** Kustomize integrating the official SeaweedFS Helm Chart.
*   **Namespace:** `seaweedfs` (Infrastructure layer).
*   **Components:** Master, Volume, Filer, and S3 API Gateway.
*   **Storage:** Local storage via OpenEBS (`openebs-hostpath`) for high I/O throughput.
*   **Security:** S3 Access Key and Secret Key will be stored in Doppler and synced via External Secrets Operator (ESO).
*   **Goal:** Establish an S3-compatible Data Lake (`mlflow-artifacts`, `bronze-logs`, `silver-enriched`) and decommission the resource-heavy MinIO deployment.

---

## Step 1: Secret Management (Doppler & ESO)
1.  **Generate S3 Credentials:** Generate secure, random strings for the S3 Access Key and Secret Key.
2.  **Store in Doppler:** Add these to the Doppler `k8s-eso` project (`dev` environment) as `SEAWEEDFS_S3_ACCESS_KEY` and `SEAWEEDFS_S3_SECRET_KEY`.
3.  **Create ExternalSecret Manifest:** Create an `ExternalSecret` to sync these credentials into the `seaweedfs` namespace.

## Step 2: Base Kustomize & Helm Configuration
1.  **Namespace Manifest:** Define the `seaweedfs` namespace.
2.  **Helm Values:** Configure the Helm chart to run a minimal topology suited for the homelab:
    *   1 Master Node
    *   1 Volume Node
    *   1 Filer Node
    *   1 S3 Gateway
    *   Enable S3 API and configure it to use the injected secret credentials.
    *   Use `openebs-hostpath` for Master and Volume persistence.
3.  **Kustomization:** Bind the resources and the Helm chart reference (version `4.22.0`).

## Step 3: Environment Overlay & ArgoCD Registration
1.  **ArgoCD App Manifest:** Create the `seaweedfs` Application manifest in the `home-dev` overlay.
2.  **Overlay Kustomization:** Append the new application to the `infrastructure/overlays/home/kustomization.yaml` registry.
3.  **Deploy:** Commit, push, and sync via ArgoCD.

## Step 4: MLflow Migration & MinIO Decommissioning
1.  **Bucket Creation:** Access the SeaweedFS S3 endpoint and create the `mlflow-artifacts` bucket.
2.  **Update MLflow Secrets:** Update MLflow's ExternalSecret to pull the new SeaweedFS S3 credentials from Doppler instead of MinIO's.
3.  **Update MLflow Deployment:** Modify `apps/base/mlflow/04-mlflow.yaml` to point the S3 endpoint to `http://seaweedfs-s3.seaweedfs.svc.cluster.local:8333`.
4.  **Purge MinIO:** Delete the `02-minio.yaml` file from the repository to trigger ArgoCD to uninstall the old storage backend.