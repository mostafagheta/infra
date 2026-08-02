variable "project_name" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "master_sg_id" {
  type = string
}

variable "worker_sg_id" {
  type = string
}

variable "bastion_sg_id" {
  type        = string
  description = "The security group ID for the bastion host"
}

variable "instance_type_master" {
  type    = string
  default = "t3.medium"
}

variable "instance_type_worker" {
  type    = string
  default = "t3.medium"
}

variable "worker_count" {
  type    = number
  default = 2
}

variable "key_name" {
  type        = string
  description = "Existing EC2 key pair name used for SSH / Ansible access"
}

variable "master_private_ip" {
  type        = string
  description = "Fixed private IP for the master node. Must be within the first public subnet CIDR."
  default     = "10.0.1.10"
}

variable "worker_private_ips" {
  type        = list(string)
  description = "Fixed private IPs for each worker node. worker[n] must be within subnet_ids[n % len(subnets)]."
  default     = ["10.0.1.20", "10.0.2.20"]
}
