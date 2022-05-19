# DevOps - Terraform

## Pre requisite

- Install Terraform (`./commands_tp3.md`)
- Install Packer (`./commands_tp3.md`)

If you're doing the following on your own machine export AWS credential keys:
```
export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

## Packer

Using the file `./web_ami/buildAMI.json` and change those parameters specific to our configuration:
- region: "eu-west-1",
- ssh_username: "ubuntu",
- base_ami: "ami-07d8796a2b0f8d29c", => used the build the temporary ec2 instance and is the base for the new AMI
- instance_type: "t2.micro",
- subnet_id: "subnet-0f00dc50bf4e0723b",
- temporary_security_group_source_cidrs": "X.X.X.X/32"

Use the command `packer validate` to validate the json file.
```
devops-efrei/terraform/web_ami on  main 
❯ packer validate buildAMI.json 
Template validated successfully.
```

```
❯ packer build buildAMI.json
```

Packer is then going to create a temporary ec2 instance based on the base_ami id given.
It will then use the given ansible playbook (`./web_ami/play.yml`) to install setup the instance.
Finally it will use this configured instance to create a new AMI.

We now have our AMI for the web app.


## Terraform

### Variables

File: `variables.tf`

We used three variables:
- region: eu-west-1
- ami_id: the id of the AMI we created previously
- base_ami_id: the AMI id of a typical Ubuntu micro ec2 instance

Since we only needed the default value of thoses variables we didn't need to define them in a file `*.tfvars`.

```
variable "region" {
    description = "The AWS region to use"
    default = "eu-west-1"
}

variable "ami_id" {
    description = "value of the AMI id"
    default = "ami-0b9c9dccd6f4d9f1b"
}

variable "base_ami_id" {
    description = "value of the base AMI id"
    default = "ami-07d8796a2b0f8d29c"
}
```

### Provider and Terraform state

File: `provider.tf`

In order to store the terraform state we created manually an s3 bucket.

![](./assets/s3-aws.png)

We can then reference this bucket in our `provider.tf` file.

```
terraform {
  backend "s3" {
    bucket         = "terraform-pl-state"
    key            = "tf_infra/terraform.tfstate"
    region         = "eu-west-1"
  }
}
```

The Terraform state represents the state of the infrastructure at a given time. Although it's not mandatory, it's a good idea to store the state in a bucket to facilitate coworking on the same project. Otherwise it will be stored locally in a   file named `terraform.tfstate`.

Before each `terraform plan` and `terraform apply` Terraform will look into the state and then compare our code to the current infrastructure. If there is a difference, Terraform will plan to create or destroy the necessary resources. It will also `refresh` the state by looking at the actual infrastructure and make the necessary change in the state.

Even if it's possible, it's better to not change the infrastructure manually because it might create conflict between the actual infrastructure and our code. Moreover, we should not change the state manually only if there is a major issue, it's even better to use the commands `terraform import` and `terraform state rm` in that situation.

---

The only **provider** we need here is AWS so we import it like so:

```
provider "aws" {
    region  = "eu-west-1"
}
```

The provider will allow us to use the AWS API to create, destroy, and manage the infrastructure.

### VPC, subnets & NAT

File: `vpc.tf`

This file contains the definition of the VPC (Virtual Private Cloud), subnets and NAT.

In order to facilitate the coding of the vpc resources we used an Amazon module.

```
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "vpc"
  cidr = "10.0.0.0/16"

  azs              = ["${var.region}a", "${var.region}b", "${var.region}c"]
  public_subnets   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
  }
}
```

A module is a collection of resources that are used together. It helps us to abstract the creation of all the necessary resources for a vpc. It also helps to avoid the repetition of the same code.

The module will create a VPC with the differents subnets provided in the `public_subnets` and `private_subnets` variables. The availability zones will be the ones provided in the `azs` variable.

It will also create the internet gateway and the route tables.

---

For the NAT instance we used the module ec2-instance from AWS, with a security group that we created.

```
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
    module.vpc
  ]
}
```

We used the base AMI to create the NAT instance. Also the security group will, as described, allow the instance to access: the internet and the instances in the private subnets.

We can use the value of the previously created resources: `subnet_id = module.vpc.public_subnets[0]`, this way we can create the NAT instance in the first subnet of the VPC. Therefor if the subnets cidr would change, we wouldn't have to change mnually the value of the `subnet_id` variable.

### Autoscaling group

File: `asg.tf`

An autoscaling group is a collection of instances that can be scaled up and down. Once initialized the ash will then scale up and down depending on the load of the instances, meaning new instances will be created automaticaly. It's also possible to define a minimum and maximum number of instances.

In order to know when to scale up and down we can define an autoscaling policy or initialize a cloud watch alarm.

```
resource "aws_placement_group" "asg_placement_group" {
  name = "asg-placement-group"
  strategy = "cluster"
}

// Lauch configuration for the ASG
resource "aws_launch_configuration" "ec2_lc" {
  name_prefix   = "ec2-lc-"
  image_id      = var.ami_id
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }
}

// Auto scaling group resource
resource "aws_autoscaling_group" "asg" {
    name = "asg-ec2-instance"
    launch_configuration = aws_launch_configuration.ec2_lc.id
    min_size = 1
    max_size = 4
    vpc_zone_identifier = module.vpc.private_subnets
    load_balancers = [ aws_elb.elb.id ]
    placement_group = aws_placement_group.asg_placement_group.name

    depends_on = [
      aws_launch_configuration.ec2_lc,
      aws_placement_group.asg_placement_group
    ]
}

// Auto scaling group policy
resource "aws_autoscaling_policy" "example" {
  name = "asg-ec2-instance-policy"
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = 1
  autoscaling_group_name = aws_autoscaling_group.asg.name
  cooldown = 300

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 40.0
  }
}
```

Prior the creation of the ASG we need to create the placement group. Then we defined a lauch configuration which is simply the configuration of the ec2 instances to launch when the asg scales up. For the `image_id` we used the id of the AMI we created earlier.

Then in the asg itself we can define the minimum and maximum number of instances to launch as well as the subnets in which the instances will be launched. The launch configuration and the placement group are also passed to the resource parameters.

Finally, we create the policy that will be used to scale up and down the ASG with the following parameters:

- **adjustment_type**: `ChangeInCapacity`

Meaning that when the asg scales up or down, it will change the number of instances by the value of the `scaling_adjustment` parameter.

- **scaling_adjustment**: 1

Meaning that when the asg scales up or down, it will change the number of instances by 1.

- **cooldown**: 300

Meaning that the asg will not scale up or down for 300 seconds after a scaling.

- **target_tracking_configuration**:
  - **predefined_metric_specification**:
    - **predefined_metric_type**: `ASGAverageCPUUtilization`
    - **target_value**: 40.0
  
Meaning that the asg will scale up when the average CPU utilization is above 40%.


### Elastic Load Balancer

File: `elb.tf`

The elastic load balancer is a simple load balancer that can be used to balance the incoming traffic.

```
resource "aws_elb" "elb" {
    name = "elb-ec2-instance"
    subnets = module.vpc.public_subnets
    security_groups = [aws_security_group.elb_sg.id]
    listener {
        instance_port = 80
        instance_protocol = "http"
        lb_port = 80
        lb_protocol = "http"
    }
    listener {
        instance_port      = 80
        instance_protocol  = "http"
        lb_port            = 443
        lb_protocol        = "https"
        ssl_certificate_id = "arn:aws:iam::123456789012:server-certificate/certName"
    }
    tags = {
        Name = "elb-ec2-instance"
    }

    depends_on = [
      aws_security_group.elb_sg // should be created before the instance
    ]
}

// Create a security group for the ELB
resource "aws_security_group" "elb_sg" {
    name        = "elb-sg"
    description = "Allow instances in the private subnets to access internet."
    vpc_id      = module.vpc.vpc_id

    egress {
        description      = "Allow private subnets access from elb"
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = module.vpc.private_subnets
    }

    ingress {
        description      = "Allow internet access to elb"
        from_port        = 80
        to_port          = 80
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
    }

    ingress {
        description      = "Allow internet access to elb"
        from_port        = 443
        to_port          = 443
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
    } 
}
```

The elb will be located in the public subnets as specified on the infrastructure diagram.

We are setting two listeners on the elb. The first one will be listening on port 80 and will be used for the HTTP protocol. The second one will be listening on port 443 and will be used for the HTTPS protocol.

For the security group we are allowing access from the internet and to the private subnets. It's logical since the elb need to redirect the traffic to the instances located in the private subnets.

If we go back to the asg we can also add the elb to the load balancers list so the asg is aware that we are using a load balancer.

### Outputs

File: `output.tf`

This file contains the outputs of our terraform code, meaning that after the apply it will print the provided values.

Even though it's optional it's useful to have the outputs of the terraform code in order to debug the terraform code or directly have informations about the deployed resources.

```
output "elb_dns_name" {
    value = aws_elb.elb.dns_name
}

output "nat_instance_id" {
    value = module.ec2_instance.id
}
```

Here we kept it simple and just print the DNS name of the elb and the id of the nat instance.
