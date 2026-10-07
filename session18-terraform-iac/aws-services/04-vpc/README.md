# AWS VPC – Virtual Private Cloud (Networking)

## What is a VPC?
A VPC is your **logically isolated private network** inside AWS. You choose the IP range, divide it into subnets, control routing and traffic, and connect it to the internet or your data centre. A VPC is **regional** and spans all Availability Zones of the Region; subnets live in **one** AZ. Every account has a *default VPC* (172.31.0.0/16) in each Region.

## CIDR
**CIDR** notation `address/prefix` defines a range: `10.0.0.0/16` = 65,536 addresses (`10.0.0.0–10.0.255.255`); `/24` = 256 addresses (AWS reserves 5 per subnet → 251 usable); `/28` is the smallest subnet. VPC size: `/16` (largest) … `/28`. Use **private ranges** (RFC 1918: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) and avoid overlaps with other VPCs/on-prem if you plan peering/VPN.

## Components
| Component | Purpose |
|---|---|
| **Subnet** | A slice of the VPC CIDR in one AZ. *Public* or *private* depending on its route table |
| **Route table** | Rules `destination → target` deciding where subnet traffic goes (`local` is always present) |
| **Internet Gateway (IGW)** | Horizontally scaled gateway that gives a VPC **two-way** internet access (needs public IP + route `0.0.0.0/0 → igw`) |
| **NAT Gateway** | Lets **private** instances reach the internet **outbound only** (updates, APIs). Lives in a public subnet, has an Elastic IP, billed per hour + data |
| **Security Group** | **Stateful** firewall on the instance/ENI; allow rules only; default deny inbound, allow all outbound |
| **Network ACL (NACL)** | **Stateless** firewall on the *subnet*; allow **and deny** rules, numbered and evaluated in order; must allow return traffic explicitly |
| **Elastic IP** | static public IPv4 |
| **VPC Endpoints** | private access to AWS services (S3 gateway endpoint, interface endpoints) without internet |
| **Peering / Transit Gateway / VPN / Direct Connect** | connect VPCs and on-premises |

### Security Group vs NACL
| | Security Group | Network ACL |
|---|---|---|
| Level | instance / ENI | subnet |
| State | **stateful** | **stateless** |
| Rules | allow only | allow + deny |
| Evaluation | all rules | in rule-number order |
| Default | deny in / allow out | default NACL allows all |

## Public vs private subnet
| | Public subnet | Private subnet |
|---|---|---|
| Route to `0.0.0.0/0` | **Internet Gateway** | NAT Gateway (or none) |
| Instances get public IP | yes (auto-assign) | no |
| Reachable from internet | yes (if SG allows) | no |
| Typical resources | load balancers, bastion, NAT GW | app servers, databases |

## Typical 3-tier architecture
```text
                       Internet
                          │
                    ┌─────▼─────┐
                    │    IGW    │
                    └─────┬─────┘
 VPC 10.0.0.0/16          │
 ┌────────────────────────┼─────────────────────────────────────┐
 │  AZ-a                  │                   AZ-b              │
 │  Public subnet 10.0.1.0/24     Public subnet 10.0.2.0/24     │
 │   [ALB] [NAT GW]                [ALB] [NAT GW]                │
 │        │                              │                       │
 │  Private subnet 10.0.11.0/24   Private subnet 10.0.12.0/24    │
 │   [App servers]                 [App servers]                 │
 │  Private subnet 10.0.21.0/24   Private subnet 10.0.22.0/24    │
 │   [RDS primary]                 [RDS standby]                 │
 └──────────────────────────────────────────────────────────────┘
 Public route table:  0.0.0.0/0 → IGW     Private route table: 0.0.0.0/0 → NAT GW
```
A working Terraform VPC project (VPC, subnet, IGW, route table, security group, EC2, S3) is in [`../../../session19-terraform-cloud-infrastructure`](../../../session19-terraform-cloud-infrastructure/README.md).

## Quick CLI
```bash
aws ec2 create-vpc --cidr-block 10.0.0.0/16
aws ec2 create-subnet --vpc-id vpc-123 --cidr-block 10.0.1.0/24 --availability-zone ap-south-1a
aws ec2 create-internet-gateway ; aws ec2 attach-internet-gateway --vpc-id vpc-123 --internet-gateway-id igw-123
aws ec2 create-route --route-table-id rtb-123 --destination-cidr-block 0.0.0.0/0 --gateway-id igw-123
```
