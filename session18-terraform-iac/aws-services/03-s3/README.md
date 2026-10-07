# AWS S3 – Simple Storage Service (Storage)

## What is S3?
S3 is **object storage** with virtually unlimited capacity, 99.999999999 % (11 nines) durability and 99.99 % availability (Standard). Data is stored as **objects** in **buckets** and accessed over HTTPS through an API/URL – it is not a file system or block disk. Regional service with a **globally unique bucket name**.

## Buckets and objects
| | Description |
|---|---|
| **Bucket** | Container for objects; name is globally unique (3–63 chars, lowercase); created in one Region |
| **Object** | The data (file, 0 B – 5 TB) + **key** (its full path/name, e.g. `logs/2026/10/app.log`) + metadata + optional version ID + tags |
| Flat namespace | "folders" are just key prefixes |
| Operations | `PUT`, `GET`, `DELETE`, `LIST`; multipart upload for big files; pre-signed URLs for temporary access |
| Consistency | strong read-after-write consistency |

## Storage classes
| Class | Use | Retrieval | Cost |
|---|---|---|---|
| **S3 Standard** | frequently accessed data | instant | highest storage cost |
| **Intelligent-Tiering** | unknown/changing access | instant (auto-moves tiers) | small monitoring fee |
| **Standard-IA** | infrequent access, multi-AZ | instant (retrieval fee) | lower |
| **One Zone-IA** | infrequent, re-creatable, one AZ | instant | cheaper |
| **Glacier Instant Retrieval** | archive, rare access | milliseconds | low |
| **Glacier Flexible Retrieval** | archive | minutes–hours | very low |
| **Glacier Deep Archive** | long-term (7–10 y) compliance | ~12 h | lowest |

## Versioning
Keeps **every version** of an object in a bucket (`Enabled` / `Suspended`; cannot be disabled once enabled). Protects against accidental overwrite/delete (a delete only adds a *delete marker*); you can restore any version. Often combined with **MFA Delete** and lifecycle rules to expire old versions.
```hcl
resource "aws_s3_bucket_versioning" "v" {
  bucket = aws_s3_bucket.b.id
  versioning_configuration { status = "Enabled" }
}
```

## Lifecycle policies
Rules that **transition** objects between classes or **expire** them automatically.
```json
{ "Rules": [{ "ID": "archive-logs", "Status": "Enabled", "Filter": {"Prefix": "logs/"},
  "Transitions": [{"Days": 30, "StorageClass": "STANDARD_IA"}, {"Days": 90, "StorageClass": "GLACIER"}],
  "Expiration": {"Days": 365}, "NoncurrentVersionExpiration": {"NoncurrentDays": 30} }] }
```

## Encryption
* **At rest (automatic since Jan 2023):** SSE-S3 (AES-256, AWS-managed keys, default), **SSE-KMS** (keys in KMS, audit via CloudTrail, per-key policies), SSE-C (customer-provided keys), or client-side encryption.
* **In transit:** HTTPS/TLS; enforce with a bucket policy condition `aws:SecureTransport`.

## Bucket policies & access control
* **Bucket policy** – resource-based JSON policy (cross-account access, enforce TLS, restrict to a VPC endpoint/IP).
* **IAM policies** for users/roles, **ACLs** (legacy – disable with *Object Ownership: bucket owner enforced*).
* **Block Public Access** – account/bucket-level safety switch (keep **ON** unless hosting a public site).
```json
{ "Version":"2012-10-17","Statement":[{ "Sid":"DenyInsecureTransport","Effect":"Deny","Principal":"*",
  "Action":"s3:*","Resource":["arn:aws:s3:::my-bucket","arn:aws:s3:::my-bucket/*"],
  "Condition":{"Bool":{"aws:SecureTransport":"false"}} }]}
```

## Common use cases
Static website hosting · backups & disaster recovery · data lake (Athena/Glue/EMR) · application assets & user uploads · log storage (CloudTrail, ALB) · software artifacts / Terraform remote state (with DynamoDB lock) · big-data and ML datasets · cross-region replication for resilience.

## CLI
```bash
aws s3 mb s3://my-unique-bucket --region ap-south-1
aws s3 cp file.txt s3://my-unique-bucket/ ; aws s3 ls s3://my-unique-bucket
aws s3 sync ./site s3://my-unique-bucket/site
aws s3 presign s3://my-unique-bucket/file.txt --expires-in 3600
```
*A working Terraform example (bucket + versioning + public-access block) is in [`../../terraform-s3-demo`](../../terraform-s3-demo/README.md).*
