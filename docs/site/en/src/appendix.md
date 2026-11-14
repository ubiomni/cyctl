# Appendix

## Default Component Version Matrix

`cyctl image build-rootfs` automatically selects matching container runtime and tool versions based on the specified K8s version:

| K8s Version | containerd | runc | crictl | registry |
|------------|-----------|------|--------|----------|
| ≤1.28 | 1.7.27 | 1.1.14 | 1.28.0 | 2.8.3 |
| 1.29 | 1.7.27 | 1.1.14 | 1.29.0 | 2.8.3 |
| 1.30 | 1.7.27 | 1.1.14 | 1.30.1 | 2.8.3 |
| 1.31 | 1.7.27 | 1.2.6 | 1.31.1 | 2.8.3 |
| 1.32 | 1.7.27 | 1.2.6 | 1.32.0 | 2.8.3 |
| 1.33 | 2.0.4 | 1.2.6 | 1.33.0 | 2.8.3 |
| 1.34+ | 2.1.1 | 1.2.6 | 1.33.0 | 2.8.3 |

> Starting from K8s 1.33, containerd 2.x is used by default. containerd 2.x removed the v1 CRI plugin config format — cyctl automatically generates the correct configuration for each version.

## Built-in Component Overview

cyctl ships with 20+ components organized around the AI data lifecycle:

| Stage | Components | Purpose |
|-------|-----------|---------|
| **Data Ingestion** | Kafka (Strimzi), NATS | Real-time data ingestion, streaming corpus collection, event-driven pipelines |
| **Data Storage** | RustFS | S3-compatible object storage for datasets, corpus, model files, checkpoints |
| **Dataset Management** | Nessie | Iceberg REST catalog, dataset versioning (track which data version each training run used) |
| **Data Processing** | Spark | Corpus cleaning, feature engineering, large-scale ETL |
| **Data Query** | Trino | Distributed SQL, query Iceberg tables to explore datasets |
| **Data Caching** | Alluxio | Hot data locality, accelerate training reads and Spark/Trino computation |
| **GPU Training** | gpu-operator, training-operator, volcano | GPU driver management, PyTorchJob/MPIJob, Gang Scheduling |
| **Inference** | KubeRay | Ray Serve model deployment, distributed inference, auto-scaling |
| **Monitoring** | Prometheus, Loki, Alloy, Grafana | GPU/node metrics, training logs, visualization, GPU-based HPA |
| **Middleware** | MySQL, Redis, PostgreSQL, Nginx | Databases, caching, gateway |
| **Analytics** | ClickHouse | Training metrics analysis, data quality statistics, OLAP |

All components support standalone and distributed deployment modes via `--profile`.
