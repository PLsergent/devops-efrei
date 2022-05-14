// Auto Scalling Group file

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

// Terraform auto scaling group resource
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
