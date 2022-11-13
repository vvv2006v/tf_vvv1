provider "aws"  {
    region="us-east-1"
}

#  VPC
resource "aws_default_vpc" "vvv2006v_vpc" {
  
  tags = {
    Name = "vvv2006v_VPC"
}

}


#  Subnets
resource "aws_default_subnet" "vvv2006v_subnet_a" {
  availability_zone = "us-east-1a"
    tags = {
    Name = "vvv2006v us-east-1a"
}
}

resource "aws_default_subnet" "vvv2006v_subnet_b" {
  availability_zone = "us-east-1b"
      tags = {
    Name = "vvv2006v us-east-1b"
}
}

resource "aws_default_subnet" "vvv2006v_subnet_c" {
  availability_zone = "us-east-1c"
      tags = {
    Name = "vvv2006v us-east-1c"
}
}

resource "aws_ecs_cluster" "vvv2006v_cluster" {
  name = "vvv2006v-cluster" # my-cluster   Naming the cluster
}

resource "aws_ecs_task_definition" "vvv2006v_task" {
  family                   = "vvv2006v-task" # Naming our first task
  container_definitions    = <<DEFINITION
  [
    {
      "name": "vvv2006v-task",
      "image": "nginx:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # Stating that we are using ECS Fargate
  network_mode             = "awsvpc"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 512         # Specifying the memory our container requires
  cpu                      = 256         # Specifying the CPU our container requires
  execution_role_arn       = "${aws_iam_role.vvv2006v_ecs_TaskExecutionRole.arn}"
}


resource "aws_iam_role" "vvv2006v_ecs_TaskExecutionRole" {
  name               = "vvv2006v_ecs_TaskExecutionRole"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "vvv2006v_ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.vvv2006v_ecs_TaskExecutionRole.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}



resource "aws_alb" "vvv2006v_application_load_balancer" {
  name               = "vvv2006v-lb-tf" # Naming our load balancer
  load_balancer_type = "application"


  subnets = [ # Referencing the default subnets
    "${aws_default_subnet.vvv2006v_subnet_a.id}",
    "${aws_default_subnet.vvv2006v_subnet_b.id}",
    "${aws_default_subnet.vvv2006v_subnet_c.id}"
  ]
  # Referencing the security group
  security_groups = ["${aws_security_group.vvv2006v_load_balancer_security_group.id}"]
  
}

# Creating a security group for the load balancer:
resource "aws_security_group" "vvv2006v_load_balancer_security_group" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic in from all sources
  }
  ingress {
    description = "Allow Port 443"
    from_port   = 443
    to_port     = 443
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

resource "aws_lb_listener" "vvv2006_https_listener" {
  load_balancer_arn = "${aws_alb.vvv2006v_application_load_balancer.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-1:564141216590:certificate/3a2f0d25-ab5e-4c2f-9849-45509c87ff89"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.vvv2006v_target_group.arn}"
  }
}
resource "aws_lb_target_group" "vvv2006v_target_group" {
  name        = "vvv2006v-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${aws_default_vpc.vvv2006v_vpc.id}" # Referencing the default VPC
}

resource "aws_lb_listener" "vvv2006v_listener" {
  load_balancer_arn = "${aws_alb.vvv2006v_application_load_balancer.arn}" # Referencing our load balancer
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.vvv2006v_target_group.arn}" # Referencing our tagrte group
  }
}
resource "aws_route53_zone" "primary" {
  name = "fractal-academy.com"
}

resource "aws_route53_record" "A" {
  allow_overwrite = true
  name    = "fractal-academy.com"
  type = "A"
  zone_id = aws_route53_zone.primary.zone_id
 
   alias {
    name  = aws_alb.vvv2006v_application_load_balancer.dns_name
    zone_id   = aws_alb.vvv2006v_application_load_balancer.zone_id
    evaluate_target_health = true
  }
  
}


resource "aws_route53_record" "NS" {
  allow_overwrite = true
  name            = "fractal-academy.com"
  ttl             = 60
  type            = "NS"
  zone_id         = aws_route53_zone.primary.zone_id

  records = [
    aws_route53_zone.primary.name_servers[0],
    aws_route53_zone.primary.name_servers[1],
    aws_route53_zone.primary.name_servers[2],
    aws_route53_zone.primary.name_servers[3],
  ]
}
resource "aws_ecs_service" "vvv2006v_service" {
  name            = "vvv2006v-service"                             # Naming our first service
  cluster         = "${aws_ecs_cluster.vvv2006v_cluster.id}"             # Referencing our created Cluster
  task_definition = "${aws_ecs_task_definition.vvv2006v_task.arn}" # Referencing the task our service will spin up
  launch_type     = "FARGATE"
  desired_count   = 3 # Setting the number of containers to 3

  load_balancer {
    target_group_arn = "${aws_lb_target_group.vvv2006v_target_group.arn}" # Referencing our target group
    container_name   = "${aws_ecs_task_definition.vvv2006v_task.family}"
    container_port   = 80 # Specifying the container port
  }

  network_configuration {
    subnets          = ["${aws_default_subnet.vvv2006v_subnet_a.id}", "${aws_default_subnet.vvv2006v_subnet_b.id}", "${aws_default_subnet.vvv2006v_subnet_c.id}"]
    assign_public_ip = true                                                # Providing our containers with public IPs
    security_groups  = ["${aws_security_group.vvv2006v_service_security_group.id}"] # Setting the security group
  }
}


resource "aws_security_group" "vvv2006v_service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = ["${aws_security_group.vvv2006v_load_balancer_security_group.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


