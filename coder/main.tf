terraform {
  required_providers {
    coderd = {
      source = "coder/coderd"
      version = "~> 0.0.12"
    }
    null = {
      source = "hashicorp/null"
      version = "~> 3.2.4"
    }
    time = {
      source = "hashicorp/time"
      version = "~> 0.13.1"
    }
  }
  backend "s3" {}
}