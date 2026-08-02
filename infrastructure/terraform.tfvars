project_name = "weather-app-k8s"
aws_region   = "us-east-1"
azs          = ["us-east-1a", "us-east-1b"]

admin_cidr = "0.0.0.0/0"
key_name   = "ansiblekey"

instance_type_master = "m7i-flex.large"
instance_type_worker = "m7i-flex.large"
worker_count         = 2

node_ports = [30008]

master_private_ip  = "10.0.11.10"
worker_private_ips = ["10.0.11.20", "10.0.12.20"]

