# Data source - fetch default VPC
data "aws_vpc" "default" {
  default = true
}

# Data source - fetch public subnets from default VPC
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security group
resource "aws_security_group" "jjk_sg" {
  name        = "${var.app_name}-sg"
  description = "Allow HTTP and HTTPS inbound"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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

# ECS Cluster
resource "aws_ecs_cluster" "jjk_cluster" {
  name = "${var.app_name}-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "jjk_task" {
  family                   = "${var.app_name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = "arn:aws:iam::119750096239:role/ecsTaskExecutionRole"

  container_definitions = jsonencode([{
    name      = "${var.app_name}-container"
    image     = var.ecr_image_uri
    essential = true
    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]
  }])
}

# ECS Service
resource "aws_ecs_service" "jjk_service" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.jjk_cluster.id
  task_definition = aws_ecs_task_definition.jjk_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.jjk_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.jjk_tg.arn
    container_name   = "${var.app_name}-container"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.https]
}

# Application Load Balancer
resource "aws_lb" "jjk_alb" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.jjk_sg.id]
  subnets            = data.aws_subnets.public.ids
}

# ALB Target Group
resource "aws_lb_target_group" "jjk_tg" {
  name        = "${var.app_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

# ALB Listener - HTTP (redirects to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.jjk_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ALB Listener - HTTPS
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.jjk_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.jjk_cert.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jjk_tg.arn
  }
}

# ACM Certificate
resource "aws_acm_certificate" "jjk_cert" {
  domain_name       = "jjk.decryptoji.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Route53 DNS validation record
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.jjk_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

# ACM certificate validation
resource "aws_acm_certificate_validation" "jjk_cert" {
  certificate_arn         = aws_acm_certificate.jjk_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Route53 hosted zone data source
data "aws_route53_zone" "main" {
  name         = "decryptoji.com"
  private_zone = false
}

# Route53 record pointing to ALB
resource "aws_route53_record" "jjk" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "jjk.decryptoji.com"
  type    = "A"

  alias {
    name                   = aws_lb.jjk_alb.dns_name
    zone_id                = aws_lb.jjk_alb.zone_id
    evaluate_target_health = true
  }
}