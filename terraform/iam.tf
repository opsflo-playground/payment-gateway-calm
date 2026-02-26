# CALM: node 'payment-api' control 'secrets-management-solution'
resource "aws_iam_role" "payment_api_task_role" {
  name               = "calm-payment-api-task-role"
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

# CALM: node 'payment-api' control 'secrets-management-solution'
resource "aws_iam_policy" "payment_api_secrets_policy" {
  name        = "calm-payment-api-secrets-policy"
  description = "Policy for Payment API to access Secrets Manager"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect   = "Allow"
        Resource = "*" # Restrict to specific secrets in production
      }
    ]
  })

  tags = local.project_tags
}

# CALM: node 'payment-api' control 'secrets-management-solution'
resource "aws_iam_role_policy_attachment" "payment_api_secrets_attachment" {
  role       = aws_iam_role.payment_api_task_role.name
  policy_arn = aws_iam_policy.payment_api_secrets_policy.arn
}

# CALM: node 'tokenization-service' control 'encryption-at-rest', 'key-management', 'access-logging'
resource "aws_iam_role" "tokenization_service_task_role" {
  name               = "calm-tokenization-service-task-role"
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

# CALM: node 'tokenization-service' control 'encryption-at-rest', 'key-management'
resource "aws_iam_policy" "tokenization_service_kms_policy" {
  name        = "calm-tokenization-service-kms-policy"
  description = "Policy for Tokenization Service to use KMS for encryption"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = "*" # Restrict to specific KMS keys in production
      }
    ]
  })

  tags = local.project_tags
}

# CALM: node 'tokenization-service' control 'access-logging'
resource "aws_iam_policy" "tokenization_service_logs_policy" {
  name        = "calm-tokenization-service-logs-policy"
  description = "Policy for Tokenization Service to write logs to CloudWatch"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:us-east-1:*:log-group:/ecs/tokenization-service:*"
      }
    ]
  })

  tags = local.project_tags
}

# CALM: node 'tokenization-service' policy attachments
resource "aws_iam_role_policy_attachment" "tokenization_service_kms_attachment" {
  role       = aws_iam_role.tokenization_service_task_role.name
  policy_arn = aws_iam_policy.tokenization_service_kms_policy.arn
}

resource "aws_iam_role_policy_attachment" "tokenization_service_logs_attachment" {
  role       = aws_iam_role.tokenization_service_task_role.name
  policy_arn = aws_iam_policy.tokenization_service_logs_policy.arn
}

# CALM: node 'fraud-detection' control 'model-monitoring'
resource "aws_iam_role" "fraud_detection_task_role" {
  name               = "calm-fraud-detection-task-role"
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

# CALM: node 'fraud-detection' control 'model-monitoring' -> access to logs and potentially S3 for models
resource "aws_iam_policy" "fraud_detection_monitoring_policy" {
  name        = "calm-fraud-detection-monitoring-policy"
  description = "Policy for Fraud Detection Service for model monitoring and logging"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "s3:GetObject", # For reading ML models from S3, if applicable
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:logs:us-east-1:*:log-group:/ecs/fraud-detection:*",
          "arn:aws:s3:::calm-fraud-models/*", # Placeholder S3 bucket for models
          "arn:aws:s3:::calm-fraud-models"
        ]
      }
    ]
  })

  tags = local.project_tags
}

# CALM: node 'fraud-detection' policy attachment
resource "aws_iam_role_policy_attachment" "fraud_detection_monitoring_attachment" {
  role       = aws_iam_role.fraud_detection_task_role.name
  policy_arn = aws_iam_policy.fraud_detection_monitoring_policy.arn
}
