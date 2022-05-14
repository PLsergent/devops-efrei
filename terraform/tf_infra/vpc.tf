// VPC file, initiate VPC and using a module

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "vpc"
  cidr = "10.0.0.0/16"

  azs              = ["${var.region}a", "${var.region}b", "${var.region}c"]
  public_subnets   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"] // Will create an internet gateway
  private_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
  }
}

// Create a Nat instance in the VPC
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = "nat-instance"

  ami                    = var.base_ami_id
  instance_type          = "t2.micro"
  key_name               = "aws-pl"
  monitoring             = true
  vpc_security_group_ids = [aws_security_group.nat_instance_sg.id]
  subnet_id              = module.vpc.public_subnets[0]

  tags = {
    Terraform   = "true"
  }

  depends_on = [
    aws_security_group.nat_instance_sg // should be created before the instance
  ]
}

// Create a security group for the NAT instance
resource "aws_security_group" "nat_instance_sg" {
  name        = "nat-instance-sg"
  description = "Allow instances in the private subnets to access internet."
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "Private subnets instances acces nat instance"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = module.vpc.private_subnets
  }

  egress {
    description      = "Allow internet access from nat instance"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nat-instance-sg"
  }

  depends_on = [
    module.vpc // should be implicit but still specified here for clarity
  ]
}