variable "project_name" {
  type    = string
  default = "weather-app-k8s"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "azs" {
  type        = list(string)
  description = "At least 2 AZs, required by the ALB"
  default     = ["us-east-1a", "us-east-1b"]
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "admin_cidr" {
  type        = string
  description = "Your IP in CIDR form (x.x.x.x/32), allowed to SSH. Never set this to 0.0.0.0/0."
  default     = "0.0.0.0/0"
}

variable "key_name" {
  type        = string
  description = "Existing EC2 key pair name"
}

variable "instance_type_master" {
  type    = string
  default = "m7i-flex.large"
}

variable "instance_type_worker" {
  type    = string
  default = "m7i-flex.large"
}

variable "worker_count" {
  type    = number
  default = 2
}

variable "node_ports" {
  type        = list(number)
  description = "NodePort(s) (>30000) the deployed Service is exposed on; ALB listens/forwards on these"
  default     = [30008]
}

variable "master_private_ip" {
  type        = string
  description = "Fixed private IP for the master node (must be within the first private subnet CIDR)."
  default     = "10.0.11.10"
}

variable "worker_private_ips" {
  type        = list(string)
  description = "Fixed private IPs for worker nodes. worker[n] must be within private_subnet_ids[n % len(subnets)]."
  default     = ["10.0.11.20", "10.0.12.20"]
}

