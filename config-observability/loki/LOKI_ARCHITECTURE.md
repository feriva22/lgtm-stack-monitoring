# Grafana Loki Architecture

> Source: https://grafana.com/docs/loki/latest/get-started/architecture/
> Scraped: 2026-06-14

---

## Table of Contents

1. [Overview](#overview)
2. [Deployment Mode: Microservices](#deployment-mode-microservices)
3. [Components](#components)
4. [Storage](#storage)
5. [Chunk Format](#chunk-format)
6. [Write Path](#write-path)
7. [Read Path](#read-path)
8. [Multi-tenancy](#multi-tenancy)
9. [Summary](#summary)

---

## Overview

Grafana Loki is a horizontally scalable, highly available, multi-tenant log aggregation system inspired by Prometheus. It is designed to be very cost-effective and easy to operate.

Unlike other logging systems, Loki is built around the idea of **only indexing metadata (labels)** about your logs — not the full text of log lines. The log data itself is compressed and stored in chunks in object storage. This makes Loki more lightweight, cheaper to operate, and simpler to scale compared to full-text indexing solutions.

All Loki components compile into a **single binary**. The `-target` flag controls which role that binary plays at runtime. In microservices mode, each component is deployed and scaled independently.

---

## Deployment Mode: Microservices

Each Loki component runs as its own independent Kubernetes Deployment or StatefulSet. This mode provides maximum flexibility, fine-grained scaling, and is the recommended approach for large production environments.

Every component is started with a dedicated `-target` flag:

| Component        | Target Flag             | Type           |
|------------------|-------------------------|----------------|
| Distributor      | `-target=distributor`   | Deployment     |
| Ingester         | `-target=ingester`      | StatefulSet    |
| Query Frontend   | `-target=query-frontend`| Deployment     |
| Query Scheduler  | `-target=query-scheduler`| Deployment    |
| Querier          | `-target=querier`       | Deployment     |
| Compactor        | `-target=compactor`     | StatefulSet    |
| Ruler            | `-target=ruler`         | Deployment     |
| Index Gateway    | `-target=index-gateway` | StatefulSet    |

Each component scales independently based on its own resource profile and load characteristics.

---

## Components

### Distributor
- First point of contact for incoming log streams (via Promtail, Grafana Alloy, etc.)
- Validates log entries (timestamps, labels, line limits)
- Shards streams and forwards to multiple ingesters via consistent hashing
- Stateless — can be scaled horizontally without coordination

### Ingester
- Receives log streams from the distributor
- Builds chunks in memory per tenant + label set combination
- Periodically flushes chunks to object storage
- Participates in a **hash ring** for replication and coordination
- Has a WAL (Write-Ahead Log) for crash recovery

### Query Frontend
- Receives LogQL queries from clients (e.g., Grafana)
- Splits large queries into sub-queries (by time range or shard)
- Queues sub-queries via the query scheduler
- Merges and caches results before returning to the client
- Stateless — can be scaled horizontally

### Query Scheduler
- Optional component that separates queue management from the query frontend
- Allows independent scaling of scheduling logic from frontend HTTP handling
- Queriers pull work from the scheduler

### Querier
- Executes LogQL sub-queries
- Fetches data from both **ingesters** (in-memory recent data) and **object storage** (historical data)
- Deduplicates results before returning upstream
- Stateless — can be scaled horizontally

### Compactor
- Runs as a background process
- Merges and deduplicates index files produced by ingesters
- Handles log retention — deletes chunks and index entries that have exceeded the configured retention period

### Ruler
- Evaluates LogQL rules and alerts on a schedule
- Compatible with Prometheus alerting rules (using LogQL metric queries)
- Sends alerts to Alertmanager

### Index Gateway
- Serves index queries from object storage
- Decouples queriers from object storage for index reads
- Caches index data for faster query performance

---

## Storage

Loki separates its storage into two categories:

### Index
A lookup table mapping **label sets (streams)** to the locations of their chunks in object storage.

Supported index formats:

| Format     | Status      | Notes                                                             |
|------------|-------------|-------------------------------------------------------------------|
| **TSDB**   | Recommended | Originally from Prometheus; extensible; required for new features |
| BoltDB     | Deprecated  | Key-value store in Go; not recommended for new deployments        |

### Chunks
Containers that hold the actual compressed log entries for a given label set and time range. Stored in object storage.

Supported object storage backends:
- Amazon S3
- Google Cloud Storage (GCS)
- Azure Blob Storage
- MinIO (S3-compatible)
- Local filesystem (not recommended for production)

---

## Chunk Format

Each chunk file has the following internal structure:

```
┌─────────────────────────────────────┐
│           Magic Number              │  4 bytes — identifies it as a Loki chunk
│           Version                   │  1 byte
│           Encoding                  │  compression codec (snappy, gzip, etc.)
├─────────────────────────────────────┤
│      Structured Metadata Labels     │  label key-value pairs (symbol table)
├─────────────────────────────────────┤
│           Data Blocks               │  one or more compressed blocks
│  ┌──────────────────────────────┐   │
│  │  Entry: Timestamp (ns)       │   │
│  │  Entry: Log Line Bytes       │   │
│  │  Entry: Symbol References    │   │  references back to metadata labels
│  └──────────────────────────────┘   │
├─────────────────────────────────────┤
│        Block Metadata Section       │
│  - Entry counts per block           │
│  - Min/max timestamps               │
│  - Block offsets                    │
└─────────────────────────────────────┘
```

Each entry inside a data block contains:
- A **nanosecond timestamp**
- The **raw log line bytes**
- **Symbol references** pointing to structured metadata label strings

---

## Write Path

```
Client (Promtail / Alloy / SDK)
        │
        ▼
   Distributor   ←── validates labels, timestamps, size limits
        │
        │  consistent hash ring
        ▼
  Ingester (N replicas)
        │
        │  builds chunks in memory
        ▼
   Object Storage  (S3 / GCS / Azure / MinIO)
```

**Step-by-step:**

1. Client sends a POST request with one or more **streams** (label set + log lines).
2. **Distributor** validates each entry (max line size, label limits, timestamp freshness).
3. The distributor uses a **consistent hash ring** to determine which ingesters own each stream.
4. The stream is forwarded to the target ingester **and its replicas** for replication.
5. Each ingester appends entries to an existing in-memory chunk, or creates a new one.
6. The distributor waits for **quorum acknowledgment** (majority of replicas) before returning HTTP 204 to the client.
7. Periodically, ingesters **flush** completed chunks to object storage and update the index.

---

## Read Path

```
Client (Grafana / LogCLI)
        │
        ▼
  Query Frontend   ←── splits query into sub-queries, caches results
        │
        ▼
  Query Scheduler  ←── queues sub-queries
        │
        ▼
     Querier        ←── executes sub-queries
        │
   ┌────┴─────┐
   ▼          ▼
Ingesters  Object Storage
(recent     (historical
  data)       data)
```

**Step-by-step:**

1. Client sends a LogQL GET request to the **Query Frontend**.
2. The frontend **splits** the query into smaller time-range or shard sub-queries.
3. Sub-queries are queued in the **Query Scheduler**.
4. **Queriers** pull sub-queries from the scheduler.
5. Each querier contacts all **ingesters** to fetch in-memory (recent) data.
6. If ingesters don't cover the full time range, queriers **lazily load data from object storage** (chunks + index).
7. Each querier **deduplicates** results from multiple ingesters (due to replication).
8. The query frontend **merges** all querier results and returns the final response.
9. Results may be **cached** (in-memory or via memcached/Redis) to accelerate repeated queries.

---

## Multi-tenancy

Loki is built for multi-tenant environments. Tenant isolation is enforced at every layer.

| Mechanism             | Detail                                                                                    |
|-----------------------|-------------------------------------------------------------------------------------------|
| **HTTP Header**       | `X-Scope-OrgID` header carries the tenant ID on every request                            |
| **Index isolation**   | Each tenant's index is stored separately in object storage                                |
| **Chunk isolation**   | Chunks are prefixed with the tenant ID path in object storage                            |
| **Single-tenant mode**| When multi-tenancy is disabled, all data is stored under the default tenant ID: `fake`    |

---

## Summary

Grafana Loki is a **label-indexed, chunk-based** log aggregation system designed for cost efficiency and horizontal scalability. Here are the key architectural takeaways:

### Core Design Principles
- **Index only labels, not log content** — keeps index size small and queries fast for label-based filtering
- **Object storage as the primary backend** — cheap, durable, cloud-native (S3/GCS/Azure/MinIO)
- **Independent component scaling** — each microservice scales on its own resource profile and traffic pattern
- **Pull-based query execution** — queriers pull work from a scheduler, enabling backpressure and fair queuing

### Write Path Highlights
- Distributors are stateless and validate/shard incoming streams
- Ingesters hold recent data in memory and flush to object storage periodically
- Replication via hash ring ensures durability; quorum writes ensure consistency

### Read Path Highlights
- Query frontend handles splitting, caching, and result merging
- Queriers fan out to both ingesters (recent) and object storage (historical)
- Deduplication happens at the querier level before merging at the frontend

### Storage Highlights
- **TSDB index** (recommended) — scalable, Prometheus-compatible, required for new features
- Chunks are compressed binary files with structured metadata and nanosecond-precision timestamps
- Compactor handles background index merging and data retention enforcement

### Deployment Mode: Microservices (This Installation)
- Each component runs as an **independent Kubernetes workload** (Deployment or StatefulSet)
- Components scale independently based on load — e.g., scale queriers during heavy read traffic without touching ingesters
- Ingesters and Compactors run as StatefulSets (need stable network identity and persistent storage)
- Distributors, Queriers, Query Frontend, Scheduler, and Ruler run as stateless Deployments
- All components communicate via gRPC internally and are wired together via Kubernetes Services

---

*Document generated from official Grafana Loki documentation.*
*Source: https://grafana.com/docs/loki/latest/get-started/architecture/*
