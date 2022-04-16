provider "aws" {
    region  = "eu-west-1"
}

terraform {
  backend "s3" {
    bucket         = "terraform-pl-state"
    key            = "tf_infra/terraform.tfstate"
    region         = "eu-west-1"
  }
}