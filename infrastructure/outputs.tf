output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "master_id" {
  value = module.compute.master_id
}

output "worker_ids" {
  value = module.compute.worker_ids
}
