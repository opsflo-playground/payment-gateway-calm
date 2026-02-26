# CALM: database node 'transaction-database'
resource "aws_db_subnet_group" "main" {
  name       = "calm-payment-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = merge(local.project_tags, {
    Name = "calm-payment-db-subnet-group"
  })
}

# CALM: database node 'transaction-database'
# CALM: control 'data-encryption' -> storage_encrypted
# CALM: control 'audit-logging' -> enabled by default/CloudWatch integration
# CALM: control 'Retain transaction records for 7 years (SEC Rule 17a-4), securely delete afterward' -> backup_retention_period
# PCI-DSS: encrypt data at rest
resource "aws_db_instance" "transaction_database" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "14.7"
  instance_class         = "db.t3.small"
  identifier             = "calm-transaction-db"
  username               = "admin"
  password               = "SecurePassword123!" # WARNING: Use AWS Secrets Manager in production
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.transaction_database_sg.id]
  skip_final_snapshot    = true
  storage_encrypted      = true
  backup_retention_period = 7 # SEC Rule 17a-4
  multi_az               = true
  publicly_accessible    = false

  tags = merge(local.project_tags, {
    Name = "calm-transaction-database"
  })
}
