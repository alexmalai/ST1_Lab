


# VPC ----------------------------------------------------------------

resource "aws_vpc" "st_lab_vpc" {
  cidr_block = "172.31.0.0/16"

   tags = {
    Name = "ST1_VPC"
  }
}

# subnets -----------------------------------------------------------------



resource "aws_subnet" "st_lab_subnet_1" {           # Public Subnets
  vpc_id     = aws_vpc.st_lab_vpc.id
  cidr_block = "172.31.1.0/24"

  tags = {
    Name = "Public Subnet 1"
  }

  availability_zone = "us-east-1a" # AZ-1

}

resource "aws_subnet" "st_lab_subnet_2" {
  vpc_id     = aws_vpc.st_lab_vpc.id
  cidr_block = "172.31.2.0/24"

  tags = {
    Name = "Public Subnet 2"
  }
  
  availability_zone = "us-east-1b" # AZ-2

}



resource "aws_subnet" "st_lab_subnet_3" {        # Private Subnets
  vpc_id     = aws_vpc.st_lab_vpc.id
  cidr_block = "172.31.3.0/24"

  tags = {
    Name = "Private Subnet 1"
  }

  availability_zone = "us-east-1a" # AZ-1

}

resource "aws_subnet" "st_lab_subnet_4" {
  vpc_id     = aws_vpc.st_lab_vpc.id
  
  cidr_block = "172.31.4.0/24"
  
  availability_zone = "us-east-1b" # AZ-2

  tags = {
    Name = "Private Subnet 2"
  }
  
  
}

# Subnet_Group for AWS_RDS

# resource "aws_db_subnet_group" "default" {
#   name       = "main"
#   subnet_ids = [aws_subnet.frontend.id, aws_subnet.backend.id]

#   tags = {
#     Name = "My DB subnet group"
#   }
# }




# EC2 -----------------------------------------------------------------------------------------------
resource "aws_instance" "ec2_st1_lab" {
  ami                    = var.image_id
  instance_type          = var.instance_type
  

  # subnet_id = aws_subnet.st_lab_subnet_3.id #subnet where it will be placed

  # security_groups = [aws_security_group.allow_web_nat.id] ---temporary

  

  # network_interface {
  #   device_index         = 0
  #   network_interface_id = aws_network_interface.web-server-nic.id

  # }

network_interface {
    network_interface_id = aws_network_interface.web-server-nic.id
    device_index         = 0
  }





  availability_zone = "us-east-1a"

  user_data            = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo systemctl start httpd.service
              sudo systemctl enable httpd.service
              sudo echo "<h1> At $(hostname -f) </h1>" > /var/www/html/index.html                   
              EOF
  #tags                 = local.common_tags    # for tags
  key_name             = var.key_name
  #iam_instance_profile = aws_iam_instance_profile.test_profile.id
}


resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.st_lab_subnet_3.id
  private_ips     = ["172.31.3.13"]
  security_groups = [aws_security_group.allow_web_nat.id]
}

resource "aws_security_group" "allow_web_nat" {
  name        = "allow_web_traffic_to_nat"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.st_lab_vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = ["aws_security_group.allow_web.id"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = ["aws_security_group.allow_web.id"]
  }
  # ingress {
  #   description = "SSH"
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}









#6. Create Security Group to allow port 22,80,443 -----------------------------------------------------------------------------------


resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.st_lab_vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}




# Elastic IP -------------------------------------------------------------------------------------

# resource "aws_eip" "bar" {
#   vpc = true

#   instance                  = aws_instance.ec2_st1_lab.id
  
#   depends_on                = [aws_internet_gateway.internet-gw]
# }

# Internet Gateway ------------------------------------------------------------------------------

resource "aws_internet_gateway" "internet-gw" {
  vpc_id = aws_vpc.st_lab_vpc.id

  tags = {
    Name = "main"
  }
}


# Nat_Gateway ------------------------------------------------------------------------------------

resource "aws_nat_gateway" "nat_gateway" {
 
  allocation_id = aws_eip.eip_nat.id
  subnet_id     = aws_subnet.st_lab_subnet_1.id

  tags = {
    Name = "gw NAT"
  }
}


resource "aws_eip" "eip_nat" {
  vpc = true

 # instance                  = aws_instance.ec2_st1_lab.id
  depends_on                = [aws_internet_gateway.internet-gw]
}




# Route Table Public -------------------------------------------------------------------------------------

resource "aws_route_table" "route_table_1" {
  vpc_id = aws_vpc.st_lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gw.id
  }

  # route {
  #   ipv6_cidr_block        = "::/0"
  #   egress_only_gateway_id = aws_egress_only_internet_gateway.foo.id
  # }

  tags = {
    Name = "main"
  }
}


resource "aws_route_table_association" "Public_a" {
  subnet_id      = aws_subnet.st_lab_subnet_1.id
  route_table_id = aws_route_table.route_table_1.id
}



# Route Table Private -------------------------------------------------------------------------------------


resource "aws_route_table_association" "Private_a" {   
  subnet_id      = aws_subnet.st_lab_subnet_3.id
  route_table_id = aws_route_table.route_table_2.id
}


resource "aws_route_table" "route_table_2" {
  vpc_id = aws_vpc.st_lab_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  # route {
  #   ipv6_cidr_block        = "::/0"
  #   egress_only_gateway_id = aws_egress_only_internet_gateway.foo.id
  # }

  tags = {
    Name = "main"
  }
}




