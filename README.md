# Weather App Infrastructure — Terraform

This document covers **only** the Terraform section of the project, located at
`infra/infrastructure/`. It provisions the AWS infrastructure for a self-managed
Kubernetes cluster (kubeadm-style, via Ansible) that runs the weather-app, fronted
by an Application Load Balancer.

## Architecture

- **VPC** with 2 public subnets and 2 private subnets, spread across 2 AZs.
- **Public subnets**: host the ALB and a bastion host (the only instance with a
  public IP).
- **Private subnets**: host the Kubernetes master (control-plane) node and worker
  nodes. These nodes have **no public IPs by design** — all SSH/Ansible access goes
  through the bastion, and cluster-internal traffic stays private.
- **NAT Gateway**: gives the private-subnet nodes outbound internet access
  (package installs, container pulls) without exposing them inbound.
- **ALB**: public entry point, forwards traffic on the configured NodePort(s) to
  the worker nodes' target groups.
- **Security groups**: one each for `alb`, `master`, `worker`, `bastion`, scoped
  as tightly as the cluster's needs allow (SSH only from `admin_cidr` via the
  bastion; NodePort traffic only from the ALB; CNI/etcd/control-plane ports
  scoped to the VPC CIDR).
- **IAM/SSM**: master and worker nodes get an instance profile with
  `AmazonSSMManagedInstanceCore`, so they're reachable via SSM Session Manager
  for troubleshooting without widening SSH access.
- **Ansible inventory generation**: after `apply`, Terraform writes
  `../ansible/inventory.ini` directly from state (bastion public IP + node
  private IPs), so Ansible always targets the infrastructure that was just
  created.

## Directory structure

```
infra/infrastructure/
├── main.tf                # wires the 4 modules together
├── variables.tf            # root-level input variables
├── outputs.tf              # root-level outputs (ALB DNS, instance IDs, etc.)
├── providers.tf             # AWS/local provider versions + S3 backend
├── inventory.tf             # renders ansible/inventory.ini from state
├── terraform.tfvars        # environment-specific variable values
├── templates/
│   └── hosts.tpl           # Ansible inventory template
└── modules/
    ├── network/            # VPC, subnets, IGW, NAT, route tables
    ├── security/            # security groups (alb, master, worker, bastion)
    ├── compute/             # EC2 instances (master, workers, bastion) + IAM
    └── alb/                 # ALB, target groups, listeners
```

## Modules

### `network`
Creates the VPC, internet gateway, public/private subnets, route tables, and a
single NAT gateway (in the first public subnet) for private-subnet egress.

**Outputs consumed downstream:** `vpc_id`, `vpc_cidr`, `public_subnet_ids`,
`private_subnet_ids`.

### `security`
Defines 4 security groups:
- `alb` — accepts inbound on the NodePort (e.g. 30008) from the internet, egresses
  to the worker NodePort range only.
- `master` — SSH from `admin_cidr`/bastion, Kubernetes API (6443), etcd,
  kubelet, scheduler, controller-manager, and CNI (Calico BGP/VXLAN, Flannel
  VXLAN kept for compatibility) — all scoped to the VPC CIDR except SSH/API.
- `worker` — SSH from `admin_cidr`/bastion, kubelet API from the VPC, CNI ports,
  and NodePort range **only from the ALB security group** (never directly from
  the internet).
- `bastion` — SSH from `admin_cidr` only.

**Outputs consumed downstream:** `alb_sg_id`, `master_sg_id`, `worker_sg_id`,
`bastion_sg_id`.

### `compute`
Provisions:
- 1 master EC2 instance (private subnet, fixed private IP)
- N worker EC2 instances (`worker_count`, spread round-robin across private
  subnets, fixed private IPs)
- 1 bastion EC2 instance (public subnet, dynamic public IP)
- A shared IAM role/instance profile for SSM access on master/workers

All instances use Amazon Linux 2023, IMDSv2-only metadata, and encrypted gp3
root volumes.

> **Note:** master and worker instances live in private subnets and therefore
> have no public IP — access is via the bastion only. Don't expect a
> `public_ip` value for these instances.

**Outputs consumed downstream:** `worker_ids` (→ ALB target group attachment),
`bastion_public_ip` (→ Ansible inventory).

### `alb`
Creates the Application Load Balancer, one target group + listener per entry in
`node_ports`, and attaches every worker instance to every target group.

**Outputs consumed downstream:** `alb_dns_name` (→ root output).

## Root-level files

- **`main.tf`** — instantiates `network` → `security` → `compute` → `alb` in
  order, passing outputs of earlier modules as inputs to later ones.
- **`variables.tf`** — all configurable inputs (project name, region, CIDRs,
  AZs, admin CIDR, instance types, worker count, node ports, fixed node IPs).
- **`outputs.tf`** — surfaces the ALB DNS name and instance IDs for reference.
- **`providers.tf`** — pins the `aws` (~> 5.0) and `local` (~> 2.4) provider
  versions, and configures the S3 backend (`weather-app-tfstate-345hagar`,
  `eu-north-1`, encrypted, with state locking).
- **`inventory.tf`** — renders `templates/hosts.tpl` into
  `../ansible/inventory.ini` using the bastion's public IP and the nodes'
  fixed private IPs, so the Ansible playbooks always have an up-to-date
  inventory after `apply`.

## Prerequisites

- Terraform `>= 1.5.0`
- AWS credentials with permission to manage VPC/EC2/IAM/ELB resources in the
  target account
- An existing EC2 key pair (name set via `key_name` in `terraform.tfvars`),
  with the matching `.pem` file available locally for Ansible
- The S3 backend bucket (`weather-app-tfstate-345hagar` in `eu-north-1`) must
  already exist and be accessible

## Usage

```bash
cd infra/infrastructure

# Initialize providers + backend
terraform init

# Review the plan
terraform plan

# Apply
terraform apply

# After apply, the Ansible inventory is auto-generated at:
#   infra/ansible/inventory.ini
```

To tear down:

```bash
terraform destroy
```

## Configuration reference (`terraform.tfvars`)

| Variable | Purpose |
|---|---|
| `project_name` | Prefix for naming/tagging all resources |
| `aws_region` | AWS region for resource deployment |
| `azs` | Availability zones (min. 2, required by the ALB) |
| `admin_cidr` | Your IP in CIDR form, allowed to SSH — **never set to `0.0.0.0/0` in production** |
| `key_name` | Existing EC2 key pair name |
| `instance_type_master` / `instance_type_worker` | EC2 instance sizes |
| `worker_count` | Number of worker nodes |
| `node_ports` | NodePort(s) the deployed Service is exposed on |
| `master_private_ip` / `worker_private_ips` | Fixed private IPs for the cluster nodes |

## Known limitations

- `admin_cidr` currently defaults to `0.0.0.0/0` in `terraform.tfvars` — this
  should be locked down to a specific IP/CIDR before any real deployment.
- The root `private_subnet_cidrs` variable exists but isn't currently passed
  into the `network` module — see the module's own default for the value
  actually in effect.
