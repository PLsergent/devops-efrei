output "elb_dns_name" {
    value = aws_elb.elb.dns_name
}

output "nat_instance_id" {
    value = module.ec2_instance.id
}