variable "project_name" {
  type        = string
  description = "Prefix used for naming/tagging all network resources"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the public subnets (min 2, in different AZs, required by the ALB)"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "azs" {
  type        = list(string)
  description = "Availability zones to spread the public subnets across"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the private subnets"
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}
