# Ansible — Kubernetes Cluster Configuration

This directory contains the Ansible automation used to configure and bootstrap a self-managed Kubernetes cluster on AWS EC2.

The infrastructure is provisioned by Terraform, while Ansible prepares the EC2 instances, installs Kubernetes dependencies, initializes the control plane, joins worker nodes, installs Calico, and deploys ingress-nginx.

## Architecture

```text
                         Internet
                            |
                            v
                    AWS Bastion Host
                     Public Subnet
                            |
                     SSH Proxy / Jump
                            |
              -----------------------------
              |                           |
       Kubernetes Master           Kubernetes Workers
        Private Subnet              Private Subnets
              |                           |
              |---------------------------|
                         |
                    Kubernetes
                     Cluster
                         |
              ----------------------
              |                    |
           Calico             ingress-nginx
                                  |
                              NodePort 30008
```

## Managed Hosts

| Host | Role | Network |
|---|---|---|
| `bastion01` | SSH Bastion | Public subnet |
| `master01` | Kubernetes Control Plane | Private subnet |
| `worker01` | Kubernetes Worker | Private subnet |
| `worker02` | Kubernetes Worker | Private subnet |

The Kubernetes nodes do not have public IP addresses. Ansible connects to them through the Bastion host.

---

## Directory Structure

```text
ansible/
├── ansible.cfg
├── site.yml
├── master_playbook.yml
├── worker_playbook.yml
├── inventory.ini
│
└── roles/
    ├── common/
    │   ├── defaults/
    │   │   └── main.yml
    │   └── tasks/
    │       └── main.yml
    │
    ├── k8s_master/
    │   ├── defaults/
    │   │   └── main.yml
    │   └── tasks/
    │       └── main.yml
    │
    └── k8s_worker/
        ├── defaults/
        │   └── main.yml
        └── tasks/
            └── main.yml
```

---

## Prerequisites

Before running Ansible, make sure you have:

- Ansible installed
- SSH client installed
- AWS infrastructure created by Terraform
- The EC2 SSH private key
- Network connectivity to the Bastion host
- Python available on the managed EC2 instances

The infrastructure should be created with Terraform before running the Ansible playbooks.

---

# Terraform → Ansible Integration

Terraform creates the AWS infrastructure and automatically generates the Ansible inventory.

The inventory is generated using:

```text
infrastructure/inventory.tf
infrastructure/templates/hosts.tpl
```

The generated inventory contains:

- Bastion public IP
- Kubernetes master private IP
- Worker private IPs
- SSH configuration
- Bastion ProxyJump configuration

The workflow is:

```text
Terraform
   |
   | Creates AWS infrastructure
   v
EC2 Instances
   |
   | Generates inventory.ini
   v
Ansible
   |
   | Configures instances
   v
Kubernetes Cluster
```

After running:

```bash
terraform apply
```

the inventory is generated in:

```text
ansible/inventory.ini
```

---

# Ansible Configuration

The `ansible.cfg` file provides the default Ansible configuration:

```ini
[defaults]
inventory = inventory.ini
remote_user = ec2-user
host_key_checking = False
timeout = 60
forks = 10

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
```

### Important Settings

#### Inventory

```ini
inventory = inventory.ini
```

Ansible automatically uses the generated inventory.

#### Remote User

```ini
remote_user = ec2-user
```

The EC2 instances use the `ec2-user` account.

#### Host Key Checking

```ini
host_key_checking = False
```

This prevents SSH host-key prompts when connecting to newly created instances.

#### SSH Pipelining

```ini
pipelining = True
```

This can reduce the number of SSH operations performed by Ansible.

---

# Inventory

The inventory is organized into:

```ini
[bastion]
bastion01

[master]
master01

[worker]
worker01
worker02

[k8s_cluster:children]
master
worker
```

The Kubernetes nodes are private instances, so Ansible uses the Bastion as an SSH proxy.

The connection path is:

```text
Ansible Controller
       |
       | SSH
       v
   Bastion Host
       |
       | SSH Proxy
       v
Private Kubernetes Node
```

---

# Playbook Structure

The main entry point is:

```text
site.yml
```

It imports:

```yaml
- import_playbook: master_playbook.yml
- import_playbook: worker_playbook.yml
```

Running:

```bash
ansible-playbook site.yml
```

performs:

1. Common configuration
2. Kubernetes master configuration
3. Worker configuration
4. Kubernetes worker joining

---

# Common Role

The `common` role prepares both master and worker nodes.

Location:

```text
roles/common/
```

It handles the following tasks.

## Disable Swap

Kubernetes requires swap to be disabled.

Ansible runs:

```bash
swapoff -a
```

and removes active swap entries from `/etc/fstab`.

This makes the configuration persistent across reboots.

---

## Configure Kernel Modules

The following kernel modules are configured:

```text
overlay
br_netfilter
```

They are stored in:

```text
/etc/modules-load.d/k8s.conf
```

and loaded using:

```bash
modprobe overlay
modprobe br_netfilter
```

---

## Configure Kernel Networking

The following sysctl parameters are configured:

```text
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
```

These settings allow Linux networking and packet forwarding to work correctly with Kubernetes.

---

## Configure SELinux

SELinux is configured in permissive mode.

This is applied both temporarily and persistently.

---

## Install Dependencies

The common role installs the required packages, including:

```text
wget
tar
containerd
socat
conntrack-tools
iproute-tc
```

---

# Containerd Configuration

Containerd is used as the Kubernetes container runtime.

A default configuration is generated with:

```bash
containerd config default > /etc/containerd/config.toml
```

The configuration enables the systemd cgroup driver:

```text
SystemdCgroup = true
```

Containerd is then enabled and restarted.

---

# Kubernetes Installation

The Kubernetes repository is configured using the Kubernetes version defined by the role variables.

The current configuration uses:

```yaml
kubernetes_version: "1.35"
```

The following components are installed:

```text
kubelet
kubeadm
kubectl
```

The kubelet service is enabled and started.

---

# Kubernetes Master Role

The master-specific configuration is located at:

```text
roles/k8s_master/
```

The role performs the following operations.

## Initialize Kubernetes

The cluster is initialized with:

```bash
kubeadm init \
  --pod-network-cidr=192.168.0.0/16
```

The task checks for:

```text
/etc/kubernetes/admin.conf
```

before initializing the cluster.

This prevents an existing control plane from being initialized again.

---

# kubectl Configuration

The Kubernetes administrator configuration is copied to:

```text
/home/ec2-user/.kube/config
```

This allows `ec2-user` to run:

```bash
kubectl get nodes
kubectl get pods
kubectl get services
```

without manually specifying the kubeconfig.

---

# Calico CNI

Calico is installed as the Kubernetes Container Network Interface.

The current version is:

```text
Calico v3.30.3
```

The pod network is:

```text
192.168.0.0/16
```

Calico provides networking between pods running on different Kubernetes nodes.

---

# Worker Join Process

After the master is initialized, Ansible generates a worker join command:

```bash
kubeadm token create --print-join-command
```

The generated command is saved on the master:

```text
/tmp/kubeadm_join_command.sh
```

Workers retrieve this command from the master and execute it.

This avoids manually copying the `kubeadm join` command.

---

# Worker Role

The worker-specific configuration is located at:

```text
roles/k8s_worker/
```

## MySQL Storage Directory

The role creates:

```text
/mnt/mysql-data
```

with the required ownership and permissions.

This directory is intended for the Kubernetes workload that uses MySQL hostPath storage.

---

## Retrieve Join Command

The worker retrieves the join command from the master using Ansible delegation:

```text
delegate_to: master
```

The command is then executed on the worker.

---

## Join Kubernetes Cluster

The worker checks for:

```text
/etc/kubernetes/kubelet.conf
```

If the file does not exist, the worker executes the generated `kubeadm join` command.

This prevents an already joined worker from joining the cluster again.

---

# Ingress-NGINX

The master role installs Helm and deploys the NGINX Ingress Controller.

The current Helm version is:

```text
v3.18.6
```

The ingress-nginx Helm repository is:

```text
https://kubernetes.github.io/ingress-nginx
```

The controller is deployed with:

```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx
```

The service type is:

```text
NodePort
```

HTTP is exposed through:

```text
30008
```

Traffic therefore follows:

```text
AWS Application Load Balancer
            |
            v
Worker Node :30008
            |
            v
ingress-nginx
            |
            v
Kubernetes Service
            |
            v
Application Pod
```

---

# Verification

After the control plane is configured, Ansible verifies access to the Kubernetes API server on:

```text
6443
```

and runs:

```bash
kubectl get nodes
```

Workers also verify that the kubelet service is running:

```bash
systemctl status kubelet
```

---

# Running the Playbooks

Move into the Ansible directory:

```bash
cd ansible
```

## Configure the Complete Cluster

```bash
ansible-playbook site.yml
```

This executes the master and worker playbooks.

---

## Configure Only the Master

```bash
ansible-playbook master_playbook.yml
```

This performs:

```text
common
  ├── Kubernetes dependencies
  ├── containerd
  ├── kernel configuration
  └── system configuration

k8s_master
  ├── kubeadm init
  ├── kubectl configuration
  ├── Calico
  ├── worker join command
  ├── Helm
  └── ingress-nginx
```

---

## Configure Only Workers

```bash
ansible-playbook worker_playbook.yml
```

This performs:

```text
common
  ├── Kubernetes dependencies
  ├── containerd
  ├── kernel configuration
  └── system configuration

k8s_worker
  ├── MySQL storage directory
  ├── retrieve join command
  ├── kubeadm join
  └── kubelet verification
```

---

# Useful Ansible Commands

### Test Connectivity

```bash
ansible all -m ping
```

### Test the Master

```bash
ansible master -m ping
```

### Test Workers

```bash
ansible worker -m ping
```

### Display Inventory Graph

```bash
ansible-inventory --graph
```

### Display Complete Inventory

```bash
ansible-inventory --list
```

### Run with Verbose Output

```bash
ansible-playbook site.yml -v
```

For detailed debugging:

```bash
ansible-playbook site.yml -vvv
```

---

# Recommended Deployment Workflow

The complete deployment should follow this order:

```text
                    Terraform
                       |
                       v
              Create AWS Network
                       |
                       v
             Create Security Groups
                       |
                       v
              Create EC2 Instances
                       |
                       v
             Create Load Balancer
                       |
                       v
             Generate inventory.ini
                       |
                       v
                     Ansible
                       |
          +------------+------------+
          |                         |
          v                         v
       Master                    Workers
          |                         |
          |                    kubeadm join
          |                         |
          +------------+------------+
                       |
                       v
                Kubernetes Cluster
                       |
                       v
                  Calico CNI
                       |
                       v
                ingress-nginx
                       |
                       v
                  NodePort 30008
                       |
                       v
                      ALB
                       |
                       v
                 Application
```

---

# Idempotency

The playbooks include checks to avoid repeating operations unnecessarily.

For example, the master checks:

```text
/etc/kubernetes/admin.conf
```

before running `kubeadm init`.

Workers check:

```text
/etc/kubernetes/kubelet.conf
```

before running `kubeadm join`.

Containerd configuration also uses file existence checks to avoid unnecessarily regenerating configuration.

This allows the playbooks to be re-run during troubleshooting or configuration changes.

---

# Troubleshooting

## Ansible Cannot Connect to Private Nodes

Start with:

```bash
ansible all -m ping
```

Then inspect:

```bash
cat inventory.ini
```

Check:

- Bastion public IP
- Master private IP
- Worker private IPs
- SSH private key
- Bastion security group
- Private node security group
- SSH connectivity from Bastion to private nodes

---

## Check Kubernetes Nodes

On the master:

```bash
kubectl get nodes -o wide
```

Expected result:

```text
NAME       STATUS   ROLES           AGE
master01   Ready    control-plane   ...
worker01   Ready    <none>          ...
worker02   Ready    <none>          ...
```

---

## Check Kubernetes System Pods

```bash
kubectl get pods -A
```

For Calico:

```bash
kubectl get pods -n kube-system
```

---

## Check Ingress-NGINX

```bash
kubectl get pods -n ingress-nginx
```

Then:

```bash
kubectl get svc -n ingress-nginx
```

The HTTP NodePort should be:

```text
30008
```

---

# Configuration Summary

| Configuration | Value |
|---|---|
| Kubernetes version | `1.35` |
| Container runtime | `containerd` |
| CNI | Calico `v3.30.3` |
| Pod CIDR | `192.168.0.0/16` |
| Kubernetes API | `6443` |
| Ingress Controller | ingress-nginx |
| Ingress Service Type | NodePort |
| HTTP NodePort | `30008` |
| Kubernetes User | `ec2-user` |
| Operating System | Amazon Linux 2023 |

---

# Security Considerations

The Kubernetes master and workers are deployed in private subnets.

SSH access follows:

```text
Your Machine
     |
     v
 Bastion
     |
     v
Private Kubernetes Nodes
```

The Kubernetes nodes should not have public IP addresses.

For production, restrict administrative CIDRs to trusted networks instead of allowing:

```text
0.0.0.0/0
```

The SSH private key must never be committed to Git.

For example:

```gitignore
*.pem
```

---

# Important Configuration Notes

The current Kubernetes version is defined as:

```yaml
kubernetes_version: "1.35"
```

Make sure the Kubernetes version is consistent across the relevant roles.

The ingress controller is configured to use:

```text
NodePort 30008
```

This must remain consistent with the AWS Load Balancer and security-group configuration in the Terraform infrastructure.

---

# End-to-End Result

After Terraform and Ansible complete successfully, the environment consists of:

```text
AWS
│
├── VPC
│
├── Public Subnets
│   ├── Bastion
│   └── Application Load Balancer
│
├── Private Subnets
│   ├── Kubernetes Master
│   ├── Kubernetes Worker 01
│   └── Kubernetes Worker 02
│
└── Kubernetes
    │
    ├── Calico CNI
    │
    ├── ingress-nginx
    │      └── NodePort 30008
    │
    └── Application
```

The purpose of this Ansible configuration is to automate the transformation of Terraform-created EC2 instances into a functional Kubernetes cluster with minimal manual intervention.
