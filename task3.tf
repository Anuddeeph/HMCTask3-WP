provider "aws" {
  region = "ap-south-1"
  profile = "anuddeeph" 
}

#create key
resource "tls_private_key" "key_create"  {
  algorithm = "RSA"
}
resource "aws_key_pair" "taskkey" {
  key_name    = "taskkey"
  public_key = tls_private_key.key_create.public_key_openssh
  }
resource "local_file" "save_key" {
    content     = tls_private_key.key_create.private_key_pem
    filename = "taskkey.pem"
}

resource "aws_vpc" "wpvpc" {
  cidr_block = "10.7.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "main"
  }
}
resource "aws_subnet" "alpha-1a" {
  vpc_id            = "${aws_vpc.wpvpc.id}"
  availability_zone = "ap-south-1a"
  cidr_block        = "10.7.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "main-1a"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.wpvpc.id}"
  tags = {
    Name = "main-1a"
  }
}
resource "aws_route_table" "rt" {
  vpc_id = "${aws_vpc.wpvpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
  tags = {
    Name = "main-1a"
  }
}
resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.alpha-1a.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "allow_http_wordpress" {
  name        = "allow_http_wordpress"
  description = "Allow HTTP inbound traffic"
  vpc_id      = "${aws_vpc.wpvpc.id}"

  ingress {
    description = "Http from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wpsgroup"
  }
}

resource "aws_subnet" "alpha-1b" {
  vpc_id            = "${aws_vpc.wpvpc.id}"
  availability_zone = "ap-south-1b"
  cidr_block        = "10.7.2.0/24"
  tags = {
    Name = "main-1b"
  }
}
resource "aws_security_group" "mysql-sg" {
  name        = "for-mysql"
  description = "MYSQL-setup"
  vpc_id      = "${aws_vpc.wpvpc.id}"

  ingress {
    description = "MYSQL from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  depends_on = [
  aws_security_group.allow_http_wordpress,
  ]

  tags = {
    Name = "mysqlsgroup"
  }
}
variable "enter_ur_key_name" {
		type = string
    	default = "taskkey"
}
resource "aws_instance" "mysql" {
  ami           = "ami-76166b19"
  instance_type = "t2.micro"
  key_name      = var.enter_ur_key_name
  availability_zone = "ap-south-1b"
  subnet_id     = "${aws_subnet.alpha-1b.id}"
  security_groups = [ "${aws_security_group.mysql-sg.id}" ]
  tags = {
    Name = "MYSQL"
  }
}
resource "aws_instance" "wordpress" {
  ami           = "ami-0979674e4a8c6ea0c"
  instance_type = "t2.micro"
  key_name      = var.enter_ur_key_name
  availability_zone = "ap-south-1a"
  subnet_id     = "${aws_subnet.alpha-1a.id}"
  security_groups = [ "${aws_security_group.allow_http_wordpress.id}" ]
  tags = {
    Name = "Wordpress"
  }
}
output "myoutaz1" {
		value = aws_instance.wordpress.availability_zone
}		
output "myoutip1" {
		value = aws_instance.wordpress.public_ip
}

resource "null_resource" "save_key_pair"  {
	provisioner "local-exec" {
	    command = "echo  '${tls_private_key.key_create.private_key_pem}' > key.pem"
  	}
}
output "key-pair" {
  value = tls_private_key.key_create.private_key_pem
}


