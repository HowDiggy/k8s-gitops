# Spark Implementation Plan (Batch AI Lakehouse)

This document outlines the technical plan for deploying the Apache Spark Kubernetes Operator to the Talos Spoke cluster to serve as the foundation for the AI-Enriched Lakehouse.

## Architecture & Constraints
*   **Deployment Method:** Kustomize integrating the official Spark Operator Helm Chart (`kubeflow/spark-operator`).
*   **Namespace:** `spark-operator` (Infrastructure layer).
*   **Webhook & Certificates:** Webhook will be enabled. It relies on the existing `cert-manager` deployment to manage the webhook TLS certificates.
*   **RBAC:** The operator requires RBAC to manage SparkApplication CRs and to allow the Spark driver to spawn executor pods.

---

## Step 1: Base Kustomize & Helm Configuration
1.  **Namespace Manifest:** Define the `spark-operator` namespace.
2.  **Helm Values:** Configure the Helm chart:
    *   Enable RBAC for both the controller and Spark applications.
    *   Enable the Webhook.
    *   Enable `certManager` integration so the operator can safely issue its webhook certificates using the in-cluster cert-manager.
3.  **Kustomization:** Bind the resources and the Helm chart reference.

## Step 2: Environment Overlay & ArgoCD Registration
1.  **ArgoCD App Manifest:** Create the `spark-operator` Application manifest in the `home-dev` overlay.
2.  **Overlay Kustomization:** Append the new application to the `infrastructure/overlays/home-dev/kustomization.yaml` registry.
3.  **Deploy:** Commit, push, and sync via ArgoCD.

## Step 3: Base Image & AI UDF Preparation (Next Phase)
1.  After the operator is running, we will need to build a custom PySpark Docker image that includes `vLLM` (or `aiohttp` to call the DGX vLLM), `delta-spark`, `pandas`, and `aioboto3`.
2.  Deploy a sample `SparkApplication` to verify the execution of batch Spark jobs against SeaweedFS.