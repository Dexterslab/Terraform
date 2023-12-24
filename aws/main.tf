provider "aws" {
  region = "us-east-2"
}

resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow all inbound and outbound traffic"

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
}

variable "instance_names" {
  description = "Names for the EC2 instances"
  type        = list(string)
  default     = ["Master", "node1", "node2", "node3"]
}

resource "aws_instance" "ec2_instance" {
  count          = length(var.instance_names)
  ami            = "ami-0bddc40b31973ff95"
  instance_type  = "t2.medium"
  key_name       = "key1"
  security_groups = [aws_security_group.allow_all.name]

user_data = <<-EOF
  #!/bin/bash
  sudo apt-get update
  sudo apt-get install -y docker.io
EOF

  tags = {
    Name = var.instance_names[count.index]
  }
}
