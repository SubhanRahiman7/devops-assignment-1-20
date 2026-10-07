# AWS Database Services – DynamoDB & RDS

AWS offers purpose-built managed databases. The two most common are **DynamoDB** (NoSQL) and **RDS** (relational).

---
# Amazon DynamoDB
## What is it?
A **fully managed, serverless NoSQL key-value/document database** with single-digit-millisecond latency at any scale. No servers to manage, automatic scaling, multi-AZ replication by default, optional global tables (multi-Region).

## NoSQL concepts
* **No fixed schema** (only the key attributes are required), data model designed around **access patterns**, horizontal scaling by partitioning, no joins.
* Consistency: eventually consistent reads (default) or strongly consistent reads; ACID transactions available.

## Data model
| Term | Meaning (relational analogy) |
|---|---|
| **Table** | collection of items (table) |
| **Item** | one record, ≤ 400 KB (row) |
| **Attribute** | a field of an item – strings, numbers, binary, lists, maps, sets (column, but different per item) |
| **Partition key** (hash key) | required; DynamoDB hashes it to choose the storage partition → must have **high cardinality** to spread load |
| **Sort key** (range key) | optional; items with the same partition key are stored sorted by it → enables range queries (`begins_with`, `between`) |
| **Primary key** | partition key alone, or partition key + sort key – uniquely identifies an item |
| **GSI / LSI** | global / local secondary indexes for other query patterns |

Example `Orders` table: partition key `customer_id`, sort key `order_date`:
| customer_id (PK) | order_date (SK) | total | status |
|---|---|---|---|
| C100 | 2026-10-01 | 540 | shipped |
| C100 | 2026-10-05 | 120 | pending |

```bash
aws dynamodb create-table --table-name Orders \
  --attribute-definitions AttributeName=customer_id,AttributeType=S AttributeName=order_date,AttributeType=S \
  --key-schema AttributeName=customer_id,KeyType=HASH AttributeName=order_date,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST
aws dynamodb put-item --table-name Orders --item '{"customer_id":{"S":"C100"},"order_date":{"S":"2026-10-01"},"total":{"N":"540"}}'
aws dynamodb query --table-name Orders --key-condition-expression "customer_id = :c" --expression-attribute-values '{":c":{"S":"C100"}}'
```
Capacity modes: **on-demand** (pay per request) or **provisioned** (RCU/WCU, with auto scaling). Extras: TTL, Streams, DAX cache, point-in-time recovery.

**Use cases:** shopping carts, user profiles/sessions, gaming leaderboards, IoT telemetry, serverless backends (Lambda), high-traffic key-value lookups, Terraform state locking.

---
# Amazon RDS (Relational Database Service)
## What is it?
A **managed relational database** service: AWS handles provisioning, OS/engine patching, automated backups, monitoring and failover while you manage schema and queries (SQL, ACID transactions, joins).

## Supported engines
MySQL · PostgreSQL · MariaDB · Oracle · Microsoft SQL Server · IBM Db2 · and **Amazon Aurora** (MySQL/PostgreSQL-compatible, cloud-native, up to 5×/3× faster, storage auto-grows to 128 TB).

## DB instances
A **DB instance** is the managed database server: engine + version, **instance class** (`db.t3.micro`, `db.m6g.large`, `db.r6g…`), storage (gp3/io1, auto-scaling), a **DB subnet group** (subnets in ≥2 AZs) and a **parameter group** for settings. You connect through an **endpoint** (DNS name) – you have no OS/SSH access.

## Security
* Place in **private subnets**, `Publicly accessible = No`; control access with **security groups** (e.g. allow 3306/5432 only from the app's security group).
* **Encryption at rest** (KMS) and **in transit** (SSL/TLS); IAM database authentication; Secrets Manager for credentials/rotation.
* Audit via CloudTrail/Enhanced Monitoring.

## Backups
* **Automated backups** – daily snapshot + transaction logs, retention 0–35 days → **point-in-time restore**.
* **Manual snapshots** – kept until deleted; copy across Regions/accounts.
* Restores create a **new** instance.

## Multi-AZ
A **synchronous standby** replica in another AZ. On failure (instance, AZ, maintenance) RDS **fails over automatically** (~1–2 min) by flipping the same endpoint's DNS. For **high availability**, not for scaling reads (standby cannot be read in the classic Multi-AZ instance setup).

## Read replicas
**Asynchronous** copies (same or other Region) that serve **read-only** traffic → scale read-heavy workloads and cross-Region DR; can be promoted to a standalone DB. Replication lag is possible.

| | Multi-AZ | Read replica |
|---|---|---|
| Purpose | high availability / failover | read scaling, DR |
| Replication | synchronous | asynchronous |
| Readable | no (standby) | yes |
| Failover | automatic | manual promotion |

**Use cases:** OLTP apps (e-commerce, ERP, CRM), WordPress/CMS, anything needing SQL/joins/transactions, reporting from read replicas.

---
## DynamoDB vs RDS
| | DynamoDB | RDS |
|---|---|---|
| Model | NoSQL key-value/document | relational tables, SQL |
| Scaling | automatic, virtually unlimited horizontal | vertical + read replicas (Aurora scales further) |
| Schema | flexible | fixed schema |
| Queries | by key/index (no joins) | complex SQL, joins |
| Management | serverless | managed instances you size |
| Best for | massive scale, simple access patterns, low latency | structured data, transactions, complex queries |
