output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "master_public_ip" {
  value = module.compute.master_public_ip
}

output "worker_public_ips" {
  value = module.compute.worker_public_ips
}

output "master_id" {
  value = module.compute.master_id
}

output "worker_ids" {
  value = module.compute.worker_ids
}
