output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "target_group_arns" {
  value = { for k, tg in aws_lb_target_group.node_port : k => tg.arn }
}
