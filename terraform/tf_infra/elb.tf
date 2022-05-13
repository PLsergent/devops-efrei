// Elastic Load Balancer file

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
        description      = "Allow internet access from elb instance"
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
    }

    ingress {
        description      = "Allow internet access to elb instance"
        from_port        = 80
        to_port          = 80
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
    }
}