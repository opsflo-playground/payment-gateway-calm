# CALM: service node 'payment-api', 'tokenization-service', 'fraud-detection'
resource "aws_ecs_cluster" "main" {
  name = "calm-payment-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.project_tags, {
    Name = "calm-payment-cluster"
  })
}

# CALM: service node 'payment-api' -> External-facing load balancer
resource "aws_lb" "main" {
  name               = "calm-payment-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  tags = merge(local.project_tags, {
    Name = "calm-payment-alb"
  })
}

# CALM: service node 'payment-api' -> Target Group for ECS service
resource "aws_lb_target_group" "payment_api_tg" {
  name        = "calm-payment-api-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(local.project_tags, {
    Name = "calm-payment-api-tg"
  })
}

# CALM: relationship 'checkout-to-payment-api' (HTTPS)
# Using dummy certificate for simplicity. In production, use a validated certificate from ACM.
resource "aws_acm_certificate" "payment_api_cert" {
  domain_name       = "payment-api.calmguard.com" # Placeholder domain
  validation_method = "DNS"

  tags = merge(local.project_tags, {
    Name = "calm-payment-api-cert"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# CALM: relationship 'checkout-to-payment-api' (HTTPS) -> ALB Listener for HTTP redirect
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
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

# CALM: relationship 'checkout-to-payment-api' (HTTPS) -> ALB Listener for HTTPS
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.payment_api_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.payment_api_tg.arn
  }
}

# CALM: ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "calm-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.project_tags
}

# CALM: ECS Task Execution Role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# CALM: service node 'payment-api'
# CALM: deployed-in relationship (implicit for container placement)
resource "aws_ecs_task_definition" "payment_api" {
  family                   = "calm-payment-api"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.payment_api_task_role.arn

  container_definitions = jsonencode([
    {
      name        = "payment-api"
      image       = "nginx:latest" # Placeholder image
      cpu         = 256
      memory      = 512
      essential   = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options   = {
          "awslogs-group"         = "/ecs/payment-api"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = merge(local.project_tags, {
    Name = "calm-payment-api-task-def"
  })
}

# CALM: service node 'payment-api'
resource "aws_ecs_service" "payment_api" {
  name            = "calm-payment-api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.payment_api.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.payment_api_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.payment_api_tg.arn
    container_name   = "payment-api"
    container_port   = 80
  }

  tags = merge(local.project_tags, {
    Name = "calm-payment-api-service"
  })
}

# CALM: service node 'tokenization-service'
# CALM: deployed-in relationship (implicit for container placement)
resource "aws_ecs_task_definition" "tokenization_service" {
  family                   = "calm-tokenization-service"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.tokenization_service_task_role.arn

  container_definitions = jsonencode([
    {
      name        = "tokenization-service"
      image       = "nginx:latest" # Placeholder image
      cpu         = 256
      memory      = 512
      essential   = true
      portMappings = [
        {
          containerPort = 443
          hostPort      = 443
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options   = {
          "awslogs-group"         = "/ecs/tokenization-service"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = merge(local.project_tags, {
    Name = "calm-tokenization-service-task-def"
  })
}

# CALM: service node 'tokenization-service'
resource "aws_ecs_service" "tokenization_service" {
  name            = "calm-tokenization-service-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.tokenization_service.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.tokenization_service_sg.id]
    assign_public_ip = false
  }

  tags = merge(local.project_tags, {
    Name = "calm-tokenization-service-service"
  })
}

# CALM: service node 'fraud-detection'
# CALM: deployed-in relationship (implicit for container placement)
resource "aws_ecs_task_definition" "fraud_detection" {
  family                   = "calm-fraud-detection"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.fraud_detection_task_role.arn

  container_definitions = jsonencode([
    {
      name        = "fraud-detection"
      image       = "nginx:latest" # Placeholder image
      cpu         = 256
      memory      = 512
      essential   = true
      portMappings = [
        {
          containerPort = 443
          hostPort      = 443
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options   = {
          "awslogs-group"         = "/ecs/fraud-detection"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = merge(local.project_tags, {
    Name = "calm-fraud-detection-task-def"
  })
}

# CALM: service node 'fraud-detection'
resource "aws_ecs_service" "fraud_detection" {
  name            = "calm-fraud-detection-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.fraud_detection.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.fraud_detection_sg.id]
    assign_public_ip = false
  }

  tags = merge(local.project_tags, {
    Name = "calm-fraud-detection-service"
  })
}
