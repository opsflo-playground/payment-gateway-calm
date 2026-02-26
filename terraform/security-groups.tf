# CALM: relationship 'checkout-to-payment-api' (HTTPS), node 'checkout-page' (webclient)
# CALM: control 'web-application-firewall-protection' on 'checkout-page'
resource "aws_security_group" "alb_sg" {
  name        = "calm-payment-alb-sg"
  description = "Allow HTTP/HTTPS from internet to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP for redirect"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(local.project_tags, {
    Name = "calm-payment-alb-sg"
  })
}

# CALM: node 'payment-api'
# CALM: relationship 'checkout-to-payment-api' (HTTPS)
# CALM: relationship 'payment-api-to-tokenization' (mTLS)
# CALM: relationship 'payment-api-to-fraud' (HTTPS)
# CALM: relationship 'payment-api-to-db' (TLS)
resource "aws_security_group" "payment_api_sg" {
  name        = "calm-payment-api-sg"
  description = "Allow inbound from ALB and outbound to internal services/DB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Allow HTTPS from ALB"
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.tokenization_service_sg.id]
    description     = "Allow outbound to Tokenization Service (mTLS)"
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.fraud_detection_sg.id]
    description     = "Allow outbound to Fraud Detection Service (HTTPS)"
  }

  egress {
    from_port       = 5432 # Default PostgreSQL port
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.transaction_database_sg.id]
    description     = "Allow outbound to Transaction Database (TLS)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all other outbound traffic"
  }

  tags = merge(local.project_tags, {
    Name = "calm-payment-api-sg"
  })
}

# CALM: node 'tokenization-service'
# CALM: relationship 'payment-api-to-tokenization' (mTLS)
# CALM: relationship 'tokenization-to-card-network' (mTLS)
resource "aws_security_group" "tokenization_service_sg" {
  name        = "calm-tokenization-service-sg"
  description = "Allow inbound from Payment API and outbound to Card Network"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.payment_api_sg.id]
    description     = "Allow mTLS from Payment API"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Assuming Card Network is external
    description = "Allow mTLS outbound to Card Network"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all other outbound traffic"
  }

  tags = merge(local.project_tags, {
    Name = "calm-tokenization-service-sg"
  })
}

# CALM: node 'fraud-detection'
# CALM: relationship 'payment-api-to-fraud' (HTTPS)
resource "aws_security_group" "fraud_detection_sg" {
  name        = "calm-fraud-detection-sg"
  description = "Allow inbound from Payment API"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.payment_api_sg.id]
    description     = "Allow HTTPS from Payment API"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(local.project_tags, {
    Name = "calm-fraud-detection-sg"
  })
}

# CALM: node 'transaction-database'
# CALM: relationship 'payment-api-to-db' (TLS)
resource "aws_security_group" "transaction_database_sg" {
  name        = "calm-transaction-database-sg"
  description = "Allow inbound from Payment API to RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432 # Default PostgreSQL port
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.payment_api_sg.id]
    description     = "Allow TLS from Payment API"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound for DB maintenance/updates"
  }

  tags = merge(local.project_tags, {
    Name = "calm-transaction-database-sg"
  })
}
