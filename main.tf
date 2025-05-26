
# Configure the AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0" # Or latest
    }
  }
}

provider "aws" {
  region = "eu-west-2" # Replace with your desired region
}

# Data sources for AZs
data "aws_availability_zones" "available" {}


# Create a security group to allow HTTP access
resource "aws_security_group" "web_sg" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"

  ingress {
    description      = "HTTP from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] # Open to the world - restrict in production
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "all"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  vpc_id = "vpc-a7ed89cf"
  
  //aws_default_vpc.default.id # Use the default VPC (or create your own)

}

# Use the default VPC (or create your own)
// data "aws_default_vpc" "default" {}

# Create a launch template
resource "aws_launch_template" "web" {
  name_prefix   = "web-server-template-"
  image_id      = "ami-0fc32db49bc3bfbb1" # Amazon Linux 2 AMI (replace with your preferred AMI)
  instance_type = "t2.micro"
  user_data = <<-EOF

#!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    echo "<html><body><h1>Hello, World! from $(hostname -f) in AZ: " > /var/www/html/index.html
    echo $AZ > /var/www/html/index.html
    echo "</h1></body></html>" > /var/www/html/index.html
  EOF
  
  
  network_interfaces {
    security_groups = [aws_security_group.web_sg.id]
  }
}



# Create an Auto Scaling group
resource "aws_autoscaling_group" "web" {
  name                      = "web-server-asg"
  min_size                  = 2 # Minimum 2 instances
  max_size                  = 2 # Maximum 2 instances (adjust as needed)
  desired_capacity          = 2
  health_check_grace_period = 300 # Give instances time to start up
 health_check_type         = "ELB" # Use ELB health checks
  vpc_zone_identifier       = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]] # Deploy across 2 AZs

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "web-server-instance-asg"
    propagate_at_launch = true
  }
}



# Create a load balancer
resource "aws_elb" "web_lb" {
 name = "web-server-lb"
  subnets         = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  security_groups = [aws_security_group.web_sg.id]

 listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }


  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "HTTP:80/"
    interval = 30
  }
  
}


# Attach the ASG to the load balancer
resource "aws_elb_attachment" "web" {
 elb        = aws_elb.web_lb.id
 instance = aws_autoscaling_group.web.id
}



# Output the DNS name of the load balancer
output "lb_dns_name" {
  value = aws_elb.web_lb.dns_name
}
