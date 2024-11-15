resource "aws_vpc" "hvpc" {
    cidr_block = var.cidr

}
resource "aws_subnet" "sub1" {
    vpc_id = aws_vpc.hvpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true

  
}
resource "aws_subnet" "sub2" {
  vpc_id = aws_vpc.hvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true


}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.hvpc.id
  
}
resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.hvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}
resource "aws_route_table_association" "rta1" {
    subnet_id = aws_subnet.sub1.id
    route_table_id = aws_route_table.RT.id
  
}
resource "aws_route_table_association" "rta2" {
    subnet_id = aws_subnet.sub2.id
    route_table_id = aws_route_table.RT.id
  
}
resource "aws_security_group" "websg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.hvpc.id


  tags = {
    Name = "web_sg"
  }
}
resource "aws_security_group_rule" "allow_http_ipv4" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Allows access from anywhere
  security_group_id = aws_security_group.websg.id
}
resource "aws_security_group_rule" "allow_ssh_ipv4" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Allows access from anywhere
  security_group_id = aws_security_group.websg.id
}
resource "aws_security_group_rule" "allow_all_traffic_ipv4" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"          # Allows all protocols
  cidr_blocks       = ["0.0.0.0/0"] # Allows traffic to any IPv4 address
  security_group_id = aws_security_group.websg.id
}
resource "aws_s3_bucket" "hibrbucket" {
  bucket = "hibri-bucket"

  
}
resource "aws_instance" "webserver1" {
  ami = "ami-0866a3c8686eaeeba"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.websg.id]
subnet_id = aws_subnet.sub1.id
user_data = base64encode(file("userdata.sh"))
}
resource "aws_instance" "webserver2" {
    ami = "ami-0866a3c8686eaeeba"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.websg.id]
    subnet_id = aws_subnet.sub2.id
    user_data = base64encode(file("userdata1.sh"))
  
}
resource "aws_lb" "hibralb" {
  name = "hibralb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.websg.id]
  subnets = [aws_subnet.sub1.id, aws_subnet.sub2.id]
  tags = {
    name = "web"
  }
   
}
resource "aws_lb_target_group" "tg" {
    name = "mytg"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.hvpc.id
    health_check {
      path = "/"
      port = "traffic-port"
    }
}
resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver1.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
   target_id       = aws_instance.webserver2.id
  port             = 80
}
resource "aws_lb_listener" "listner" {
  load_balancer_arn = aws_lb.hibralb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.tg.arn 
    type             = "forward"
  }

}
output "loadbalancerdns" {
    value = aws_lb.hibralb.dns_name
  
}