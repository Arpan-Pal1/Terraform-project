resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr

}

resource "aws_subnet" "subnet1" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}


resource "aws_subnet" "subnet2" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}


resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta1" {
  subnet_id = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rt.id
}




resource "aws_security_group" "allow_tls" {
  name        = "websg"
  vpc_id      = aws_vpc.myvpc.id

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_internet" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ssh" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


resource "aws_s3_bucket" "example" {
  bucket = "arpan-terraform-s3-12345"
}


resource "aws_instance" "myserver1" {
  ami = "ami-080e1f13689e07408"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_tls.id]
  subnet_id = aws_subnet.subnet1.id
  user_data = base64encode(file("userdata.sh"))
}

resource "aws_instance" "myserver2" {
  ami = "ami-080e1f13689e07408"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_tls.id]
  subnet_id = aws_subnet.subnet2.id
  user_data = base64encode(file("userdata2.sh"))
}

resource "aws_lb" "lb" {
  name = "web-load-balancer"
  load_balancer_type = "application"
  security_groups = [aws_security_group.allow_tls.id]
  subnets = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  tags = {
    Name = "Web"
  }
}


resource "aws_alb_target_group" "web_target" {
  name = "web-target-group"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.myvpc.id
  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "tg-attachment1" {
  target_group_arn = aws_alb_target_group.web_target.arn
  target_id = aws_instance.myserver1.id
  port = 80
}

resource "aws_lb_target_group_attachment" "tg-attachment2" {
  target_group_arn = aws_alb_target_group.web_target.arn
  target_id = aws_instance.myserver2.id
  port = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.lb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.web_target.arn
    type = "forward"
  }
}

output "loadbalancerdns" {
  value = aws_lb.lb.dns_name
}