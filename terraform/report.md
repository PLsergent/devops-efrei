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

### VPC, subnets & NAT

### Autoscaling group

### Elastic Load Balancer