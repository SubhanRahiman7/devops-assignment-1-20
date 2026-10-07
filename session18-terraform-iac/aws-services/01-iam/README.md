# AWS IAM – Identity and Access Management (Governance)

## What is IAM?
IAM is the AWS service that controls **who** (authentication) can do **what** (authorization) on **which resources**. It is **global** (not tied to a Region) and free. Every API call to AWS – from the console, CLI, SDK or Terraform – is evaluated by IAM.

## Core building blocks
| Concept | Description | Example |
|---|---|---|
| **Root user** | The account owner (email + password). Unlimited power → protect with MFA, do not use daily | `root@company.com` |
| **User** | A person or application with long-term credentials (password, access keys) | `subhan` |
| **Group** | A collection of users; attach policies once, all members inherit | `Developers`, `Admins` |
| **Role** | An identity **assumed temporarily** (no permanent password/keys) by a user, AWS service or another account. Gives short-lived credentials via STS | role `EC2-S3-ReadOnly` assumed by an EC2 instance |
| **Policy** | JSON document that lists permissions | `AmazonS3ReadOnlyAccess` |
| **Permissions** | The allowed/denied actions in policies | `s3:GetObject` |

### Users vs Groups vs Roles
```text
User ──member of──► Group ──has──► Policies (permissions)
Service/User/Account ──assume──► Role ──has──► Policies  (temporary credentials)
```
Use **roles** for workloads (EC2, Lambda, ECS, EKS, CI/CD) instead of embedding access keys.

## Policies
A policy statement has **Effect**, **Action**, **Resource** and optional **Condition**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": ["arn:aws:s3:::my-bucket", "arn:aws:s3:::my-bucket/*"],
      "Condition": { "IpAddress": { "aws:SourceIp": "203.0.113.0/24" } }
    }
  ]
}
```
| Policy type | Attached to | Notes |
|---|---|---|
| **AWS managed** | users/groups/roles | maintained by AWS (`AdministratorAccess`, `ReadOnlyAccess`) |
| **Customer managed** | users/groups/roles | your own reusable policy |
| **Inline** | one identity | embedded, 1:1 – avoid unless needed |
| **Resource-based** | a resource (S3 bucket policy, SQS) | has a `Principal` |
| **Trust policy** | a role | says *who may assume* the role |
| **Permission boundary / SCP** | user/role / AWS Organizations | maximum permissions limit |

**Evaluation logic:** everything is **denied by default** → an explicit **Allow** is needed → an explicit **Deny always wins**.

## Least privilege
Grant only the permissions required for the task and nothing more.
* Start with no permissions, add what is needed (use *IAM Access Analyzer* and *last-accessed data* to trim).
* Scope `Resource` to specific ARNs, avoid `"Action": "*"` / `"Resource": "*"`.
* Use conditions (source IP, MFA, tags, time).
* Prefer roles + short-lived credentials; separate duties (dev/prod accounts).

## IAM best practices
1. Lock away the **root user**, enable **MFA** on it, create admin IAM users/roles instead, never create root access keys.
2. Enforce **MFA** for all human users.
3. Use **groups** for permissions, **roles** for applications.
4. Apply **least privilege**; review regularly (Access Analyzer, credential report).
5. **Rotate/disable** unused access keys; never hard-code keys in code or Git (use Secrets Manager, OIDC for GitHub Actions).
6. Strong password policy; use **IAM Identity Center (SSO)** for workforce access.
7. Use conditions, permission boundaries and SCPs for guardrails.
8. Enable **CloudTrail** to audit all IAM/API activity.

## Common use cases
| Use case | How |
|---|---|
| Developer needs read access to S3 | add user to a group with `AmazonS3ReadOnlyAccess` |
| EC2 app must write to S3/DynamoDB | EC2 **instance profile** with a role (no keys on the server) |
| CI/CD (GitHub Actions) deploys to AWS | role trusted by the GitHub OIDC provider |
| Cross-account access | role in account B trusted by account A |
| Lambda accesses other services | Lambda execution role |
| Temporary access for a contractor | role + STS with expiry and MFA condition |

## CLI/Terraform quick reference
```bash
aws iam create-user --user-name demo
aws iam attach-user-policy --user-name demo --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
aws sts get-caller-identity          # who am I?
```
```hcl
resource "aws_iam_role" "ec2_role" {
  name               = "ec2-s3-readonly"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}
resource "aws_iam_role_policy_attachment" "s3_ro" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}
```
