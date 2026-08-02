terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }

  # Recommended (set up once, outside this config, then uncomment):
  # backend "s3" {
  #   bucket         = "<your-tfstate-bucket>"
  #   key            = "weather-app/terraform.tfstate"
  #   region         = "<region>"
  #   encrypt        = true
  #   dynamodb_table = "<your-lock-table>"
  # }
}

provider "aws" {
  region = var.aws_region
}
