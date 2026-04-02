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

output "cloudwatch_alarm_arn" {
  description = "ARN of the high CPU alarm, null when monitoring is disabled"
  value       = local.enable_monitoring ? aws_cloudwatch_metric_alarm.high_cpu[0].arn : null
}

output "blue_target_group_arn" {
  description = "ARN of the blue target group"
  value       = aws_lb_target_group.blue.arn
}

output "green_target_group_arn" {
  description = "ARN of the green target group"
  value       = aws_lb_target_group.green.arn
}