variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type        = string
  description = "Used to scope cluster-internal-only rules (etcd, scheduler, controller-manager, CNI overlay)"
}

variable "admin_cidr" {
  type        = string
  description = "CIDR allowed to SSH into the nodes (e.g. your office/VPN IP as x.x.x.x/32). Never leave this as 0.0.0.0/0."
}

variable "node_port_range_start" {
  type    = number
  default = 30000
}

variable "node_port_range_end" {
  type    = number
  default = 32767
}
