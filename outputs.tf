output "alb_dns_name" {
  value       = aws_lb.web.dns_name
  description = "The domain name of the load balancer"
}

output "asg_name" {
  value       = aws_autoscaling_group.web.name
  description = "The name of the Auto Scaling Group"
}

output "autoscaling_policy_arns" {
  description = "Map of autoscaling policy name to ARN"
  value       = { for p in aws_autoscaling_policy.scale_out : p.name => p.arn }
}