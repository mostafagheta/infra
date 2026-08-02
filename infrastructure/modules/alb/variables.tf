variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type        = list(string)
  description = "Must span at least 2 AZs (ALB requirement)"
}

variable "alb_sg_id" {
  type = string
}

variable "worker_instance_ids" {
  type        = list(string)
  description = "The 2 worker EC2 instance IDs the ALB target groups attach to"
}

variable "node_ports" {
  type        = list(number)
  description = "NodePort(s) (>30000) that the deployed Service(s) are exposed on. One target group + listener is created per port."
  default     = [30008]
}
