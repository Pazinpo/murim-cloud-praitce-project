# 1. 어느 클라우드에 지을 것인가? (AWS 서울 리전)
provider "aws" {
  region = "ap-northeast-2"
}

# 2. 무엇을 지을 것인가? (murim의 가상 영토 VPC 생성)
resource "aws_vpc" "murim_vpc" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "Murim-Cloud-VPC"
  }
}


# 3. 영토 안의 '구역(Subnet)' 나누기
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.murim_vpc.id  # 아까 만든 VPC의 ID를 자동으로 끌어옴
  cidr_block              = "10.0.1.0/24"         # 10.0.0.0/16 영토 안의 더 작은 구역
  availability_zone       = "ap-northeast-2a"     # 서울의 a구역 데이터센터 사용
  map_public_ip_on_launch = true                  # 이 구역에 지어지는 집(서버)은 외부 주소(공인 IP)를 받음

  tags = {
    Name = "Murim-Public-Subnet"
  }
}

# 4. 외부 세계와 통하는 '대문(Internet Gateway)' 달기
resource "aws_internet_gateway" "murim_igw" {
  vpc_id = aws_vpc.murim_vpc.id

  tags = {
    Name = "Murim-IGW"
  }
}

# 5. 인터넷으로 나가는 길 안내판(Route Table) 만들기
resource "aws_route_table" "public_rt" {
   vpc_id = aws_vpc.murim_vpc.id

   route {
	cidr_block = "0.0.0.0/0"
	gateway_id = aws_internet_gateway.murim_igw.id
   }

   tags = {
	Name = "Murim-Public-RT"
   }
}

# 6. 안내판을 구역(Subnet)에 세우기 (연결)
resource "aws_route_table_association" "public_rt_assoc"{
	subnet_id	= aws_subnet.public_subnet.id
	route_table_id	= aws_route_table.public_rt.id
}

# 7. 보안그룹 설정(Security Group)
resource "aws_security_group" "murim_sg" {
  name        = "murim-sg"
  vpc_id      = aws_vpc.murim_vpc.id

  # SSH (22번 포트): 대협이 터미널로 접속할 길
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP (80번 포트): 웹사이트 접속용
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # App (8080번 포트): 우리 스프링 부트 앱용
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 밖으로 나가는 트래픽 (전부 허용)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Murim-SG"
  }
}

# 8. 진짜 서버(EC2 Instance) 세우기
resource "aws_instance" "murim_server" {
  ami           = "ami-040c33c6a51fd5d96" # Ubuntu 24.04 (서울 리전 기준)
  instance_type = "t3.micro"

  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.murim_sg.id]
  # 어제 만든 키 페어 이름
  key_name = "murim-key"

  user_data = <<-EOF
#!/bin/bash
sudo apt-get update -y
sudo apt-get install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu
EOF


  #[핵심] 주문서가 바뀌면 서버를 아예 새로 지으라는 명령
  user_data_replace_on_change = true

  tags = {
    Name = "Murim-Terraform-Server"
  }
}

# 9. 완성 후 서버의 주소(IP)를 화면에 바로 띄워라!
output "server_public_ip" {
  value = aws_instance.murim_server.public_ip
}
