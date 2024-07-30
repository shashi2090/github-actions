terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 4.0"
    }
  }
  required_version = ">=1.0.0"
}

provider "aws" {
  region = "us-east-1"

}

terraform {
  backend "s3" {
    bucket = "shashiterraformbucket"
    key    = "statefile/terraform.tfstate"
    region = "us-east-1"
  }
}