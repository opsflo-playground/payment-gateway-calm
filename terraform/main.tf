terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  project_tags = {
    Project   = "calmguard"
    ManagedBy = "terraform"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}
