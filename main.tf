provider "aws" {
  region = "eu-central-1"
}

locals {
  is_production = var.environment == "production"

  instance_type     = local.is_production ? "t2.medium" : "t2.micro"
  min_size          = local.is_production ? 3 : 2
  max_size          = local.is_production ? 10 : 3
  enable_monitoring = local.is_production
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_vpc" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  tags = {
    Name = "existing-vpc"
  }
}

locals {
  vpc_id = var.use_existing_vpc ? data.aws_vpc.existing[0].id : data.aws_vpc.default.id
}

resource "aws_security_group" "instance_sg" {
  name = "${var.cluster_name}-instance-sg"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb_sg" {
  name = "${var.cluster_name}-alb-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_template" "web" {
  name_prefix            = "${var.cluster_name}-"
  image_id               = "ami-0cebfb1f908092578"
  instance_type          = local.instance_type
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              # version: 2
              apt-get update -y
              apt-get install -y apache2
              systemctl start apache2
              systemctl enable apache2
              echo "<h1>Hello from ${var.cluster_name} - v1</h1>" > /var/www/html/index.html
              EOF
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web" {
  name_prefix         = "${var.cluster_name}-"
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns   = [aws_lb_target_group.web.arn, aws_lb_target_group.blue.arn, aws_lb_target_group.green.arn]
  health_check_type   = "ELB"
  min_size            = local.min_size
  max_size            = local.max_size

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-instance"
    propagate_at_launch = true
  }
  tag {
    key                 = "ManagedBy"
    value               = var.custom_tag
    propagate_at_launch = true
  }
}

resource "aws_lb" "web" {
  name               = "${var.cluster_name}-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb_sg.id]
}

resource "aws_lb_target_group" "web" {
  name     = "${var.cluster_name}-tg"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = local.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
resource "aws_autoscaling_policy" "scale_out" {
  count                  = var.enable_autoscaling ? 1 : 0
  name                   = "${var.cluster_name}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_in" {
  count                  = var.enable_autoscaling ? 1 : 0
  name                   = "${var.cluster_name}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = local.enable_monitoring ? 1 : 0

  alarm_name          = "${var.cluster_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU utilization exceeded 80%"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}

resource "aws_lb_target_group" "blue" {
  name     = "${var.cluster_name}-blue-tg"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = local.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group" "green" {
  name     = "${var.cluster_name}-green-tg"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = local.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "blue_green" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = var.active_environment == "blue" ? aws_lb_target_group.blue.arn : aws_lb_target_group.green.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}