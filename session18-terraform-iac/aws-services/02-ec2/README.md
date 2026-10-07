# AWS EC2 – Elastic Compute Cloud (Compute)

## What is EC2?
EC2 provides **resizable virtual servers (instances)** in the cloud. You choose the operating system, CPU/RAM, storage and networking, pay per second (On-Demand/Spot/Reserved/Savings Plans), and can launch or terminate servers in minutes. EC2 is a **regional** service; each instance lives in one Availability Zone.

## Key concepts
| Concept | Meaning |
|---|---|
| **AMI** (Amazon Machine Image) | Template with OS + software used to launch an instance (Amazon Linux, Ubuntu, Windows, or your own custom image). Region-specific, ID like `ami-0abc…` |
| **Instance type** | Hardware profile `family.size`: `t3.micro` (burstable general purpose), `m6i.large` (general), `c6i` (compute), `r6i` (memory), `g5` (GPU), `i4i` (storage). Graviton types end in `g` (arm64) |
| **Key pair** | Public/private SSH key; AWS stores the public key, you keep the `.pem` private key (Linux SSH, or decrypt the Windows password). Alternative: SSM Session Manager |
| **Security group** | **Stateful virtual firewall** at the instance (ENI) level: allow rules only (inbound/outbound); return traffic is automatically allowed |
| **EBS** (Elastic Block Store) | Network-attached **persistent block storage** (gp3, io2, st1, sc1). Survives stop/start; snapshots go to S3. *Instance store* = ephemeral disk lost on stop |
| **Public vs private IP** | **Private IP**: fixed inside the VPC for the instance's life. **Public IP**: auto-assigned, changes on stop/start. **Elastic IP**: static public IPv4 you own until released |
| **User data** | Script run at first boot (install nginx, etc.) |
| **IAM instance profile** | Role attached to the instance for AWS API access without keys |

## Instance lifecycle
```text
        launch
          │
       pending ──► running ◄──────────────┐
                    │   │                 │ start
          reboot ◄──┘   ├─► stopping ─► stopped ─► (start) ─┘
                        │
                        └─► shutting-down ─► terminated  (cannot be restarted; EBS root volume deleted by default)
        (hibernate: stopping ─► stopped with RAM saved to EBS)
```
| State | Billed for compute? | Notes |
|---|---|---|
| pending | no | starting |
| running | **yes** | normal |
| stopping/stopped | no (EBS storage + Elastic IP still billed) | public IP is released (unless Elastic IP) |
| terminated | no | instance deleted permanently |

## Common use cases
* Web/application servers, APIs (behind an ALB, in an Auto Scaling Group).
* Batch/data processing, CI build agents, game servers.
* Hosting databases yourself (or use RDS), dev/test environments, bastion hosts.
* Lift-and-shift of on-premises servers.

## Launch with the CLI and Terraform
```bash
aws ec2 run-instances --image-id ami-0abcdef1234567890 --instance-type t3.micro \
  --key-name my-key --security-group-ids sg-123 --subnet-id subnet-123 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=web}]'
aws ec2 describe-instances --query "Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]"
aws ec2 stop-instances --instance-ids i-0123456789abcdef0
aws ec2 terminate-instances --instance-ids i-0123456789abcdef0
```
```hcl
resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = var.key_name
  tags = { Name = "web" }
}
```
**Best practices:** use IAM roles (not keys), restrict SSH (22) to your IP or use Session Manager, patch regularly, encrypt EBS, use Auto Scaling + load balancers, right-size instances, tag everything, stop dev instances when idle.
