# Configure the AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-west-2" # Replace with your desired region
}

# Create an RDS instance
resource "aws_db_instance" "postgres" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "14.5"
  instance_class       = "db.t3.micro"
  identifier           = "my-postgres-db"
  username             = "myuser"
  password             = "mypassword" # **Important: Securely manage this password**
  skip_final_snapshot = true
  db_name              = "mylistdb"
  publicly_accessible = true # **Important: Consider security implications**
}

# Create a security group for the RDS instance
resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Allow inbound traffic to RDS"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # **Important: Restrict this in production**
  }
}

# Associate the security group with the RDS instance
resource "aws_db_instance" "postgres" {
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}

# Create an EC2 instance
resource "aws_instance" "webserver" {
  ami           = "ami-0c55b31ad2299a701" # Replace with a suitable Amazon Linux AMI
  instance_type = "t2.micro"
  key_name      = "your_key_pair_name" # Replace with your key pair name

  vpc_security_group_ids = [aws_security_group.webserver_sg.id]

  tags = {
    Name = "my-web-app"
  }
}

# Create a security group for the EC2 instance
resource "aws_security_group" "webserver_sg" {
  name        = "webserver-security-group"
  description = "Allow inbound traffic to webserver"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # **Important: Restrict this in production**
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # **Important: Restrict this in production**
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ... (Existing RDS configuration remains the same) ...

# Define the existing S3 bucket (no need to create it)
variable "s3_bucket_name" {
  type = string
  description = "Name of the existing S3 bucket"
}

variable "s3_bucket_region" {
  type = string
  description = "Region of the existing S3 bucket"
}


# Create an EC2 instance with user data to download files
resource "aws_instance" "webserver" {
  # ... (Existing EC2 configuration) ...

  user_data = <<-EOF
#!/bin/bash
yum update -y
yum install python3 -y
yum install python3-pip -y
pip3 install Flask psycopg2-binary
mkdir -p /var/www/html/templates
aws s3 cp s3://jd-app-files-4-jul-25/app.py /var/www/html/
aws s3 cp s3://jd-app-files-4-jul-25/templates/ /var/www/html/templates/
chmod +x /var/www/html/app.py
chown ec2-user:ec2-user /var/www/html/templates
systemctl start httpd
systemctl enable httpd
EOF
}

# ... (Existing outputs) ...# ... (Existing outputs) ...

# Output the public IP address of the EC2 instance
output "public_ip" {
  value = aws_instance.webserver.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}