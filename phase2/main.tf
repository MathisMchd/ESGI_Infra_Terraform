provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_security_group" "cloud9" {
  id = "sg-0ae954b87d912d6a0"
}


data "aws_iam_instance_profile" "lab_profile" {
  name = "LabInstanceProfile"
}

resource "aws_security_group" "sg_phase_2" {
  name   = "sg_phase_2"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
}

resource "aws_security_group" "rds_sg_phase_2" {
  name   = "rds_sg_phase_2"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"

    security_groups = [
      aws_security_group.sg_phase_2.id,
      data.aws_security_group.cloud9.id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "projet_terraform_phase2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.sg_phase_2.id]
  iam_instance_profile   = data.aws_iam_instance_profile.lab_profile.name

  user_data = file("UserdataScript-phase-3.sh")

  tags = {
    Name = "projet-terraform-phase2"
  }
}

resource "aws_db_subnet_group" "subnet_phase_2" {
  name       = "subnet_phase_2"
  subnet_ids = data.aws_subnets.default.ids
}

resource "aws_db_instance" "mysql_instance" {
  engine               = "mysql"
  identifier           = "rdsinstance"
  allocated_storage    = 20
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = "myrdsuser"
  password             = "myrdspassword"
  db_name              = "STUDENTS"

  db_subnet_group_name   = aws_db_subnet_group.subnet_phase_2.name
  vpc_security_group_ids = [aws_security_group.rds_sg_phase_2.id]

  publicly_accessible = false
  skip_final_snapshot = true
}