output "master_id" {
  value = aws_instance.master.id
}


output "master_private_ip" {
  value = aws_instance.master.private_ip
}

output "worker_ids" {
  value = [for w in aws_instance.worker : w.id]
}


output "worker_private_ips" {
  value = [for w in aws_instance.worker : w.private_ip]
}

output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "The dynamically assigned public IP of the bastion host"
}
