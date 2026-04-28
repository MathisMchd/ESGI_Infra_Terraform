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

  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d", "us-east-1f"]
  }
}

data "aws_iam_instance_profile" "lab_profile" {
  name = "LabInstanceProfile"
}

resource "aws_secretsmanager_secret" "db_secret" {
  name_prefix = "rds-app-secret-"
  description = "Database secret for web app"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "db_secret" {
  secret_id = aws_secretsmanager_secret.db_secret.id

  secret_string = jsonencode({
    user     = aws_db_instance.mysql_instance.username
    password = aws_db_instance.mysql_instance.password
    host     = aws_db_instance.mysql_instance.address
    db       = aws_db_instance.mysql_instance.db_name
  })
}

resource "aws_security_group" "security_group" {
  name        = "phase3_app_sg"
  description = "Allow SSH and HTTP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb" {
  name        = "alb_phase_3"
  description = "Allow inbound HTTP to the application load balancer"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
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
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"

    security_groups = [
      aws_security_group.security_group.id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "subnet_phase_2" {
  name       = "subnet_phase_2"
  subnet_ids = data.aws_subnets.default.ids
}

resource "aws_db_instance" "mysql_instance" {
  engine            = "mysql"
  identifier        = "rdsinstance"
  allocated_storage = 20
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  username          = "myrdsuser"
  password          = "myrdspassword"
  db_name           = "STUDENTS"

  db_subnet_group_name   = aws_db_subnet_group.subnet_phase_2.name
  vpc_security_group_ids = [aws_security_group.rds_sg_phase_2.id]

  publicly_accessible = false
  skip_final_snapshot = true
}

resource "aws_lb" "app" {
  name                       = "phase3-app-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = data.aws_subnets.default.ids
  enable_deletion_protection = false
}

resource "aws_lb_target_group" "app" {
  name        = "phase3-app-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-399"
    path                = "/"
    timeout             = 5
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "phase3-app-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = data.aws_iam_instance_profile.lab_profile.name
  }

  vpc_security_group_ids = [aws_security_group.security_group.id]

  user_data = base64encode(file("${path.module}/UserdataScript-phase-3.sh"))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "projet-terraform-phase3"
    }
  }

  # FIX: Attendre que le secret RDS soit créé avant de lancer les instances
  # Sinon le user-data script échoue car le secret n'existe pas encore
  depends_on = [aws_secretsmanager_secret_version.db_secret]
}

resource "aws_autoscaling_group" "app" {
  name_prefix      = "phase3-app-asg-"
  desired_capacity = 2
  max_size         = 4
  min_size         = 2

  # FIX: Utiliser vpc_zone_identifier (subnet IDs) au lieu de availability_zones
  # Nécessaire pour que l'ASG soit dans le même VPC que l'ALB
  vpc_zone_identifier = data.aws_subnets.default.ids

  health_check_type         = "ELB"
  health_check_grace_period = 300
  target_group_arns         = [aws_lb_target_group.app.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "projet-terraform-phase3"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
