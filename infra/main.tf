resource "aws_iam_role" "terraform_role" {
  name = "terraformrole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::905418423522:user/terraform"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "terraform_policy" {
  name        = "TerraformPolicy"
  description = "Policy for Terraform to manage AWS resources"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:*",
          "s3:*",
          "vpc:*",
          "iam:*"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "name" {
  role       = aws_iam_role.terraform_role.name
  policy_arn = aws_iam_policy.terraform_policy.arn

}

resource "aws_iam_instance_profile" "terraform_profile" {
  name = "TerraformInstanceProfile"
  role = aws_iam_role.terraform_role.name
}

resource "aws_vpc" "actions_vpc" {
  cidr_block = var.cidr_block
  tags = {
    name = "actions_vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.actions_vpc.id
  cidr_block              = var.public_subnet
  map_public_ip_on_launch = true
  tags = {
    name = "public_subnet"
  }
}


resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.actions_vpc.id
  cidr_block = var.private_subnet
  tags = {
    name = "private_subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.actions_vpc.id
  tags = {
    name = "main-igw"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.actions_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
}

# Security Group allowing only specific traffic and all traffic
resource "aws_security_group" "specific" {
  name        = "specific_sg"
  description = "Allow SSH, HTTP, and all inbound traffic"
  vpc_id      = aws_vpc.actions_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "http"
  }
}

# EC2 Instance
resource "aws_instance" "web" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.specific.id]

  user_data = <<-EOF
                #!/bin/bash
                yum update -y
                yum install -y httpd
                systemctl start httpd
                systemctl enable httpd
                TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"` \
                && curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/
                INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
                PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
                echo "<h1>Instance ID: $INSTANCE_ID</h1>" > /var/www/html/index.html
                echo "<h1>Public IP: $PUBLIC_IP</h1>" >> /var/www/html/index.html
              EOF

  tags = {
    Name = "action-instance"
  }
}

output "instance_public_ip" {
  value = aws_instance.web.public_ip
}

