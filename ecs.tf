resource "aws_ecs_cluster" "main" {
  name = "cb-cluster"
}

data "template_file" "cb_app" {
  template = file("./templates/ecs/cb_app.json.tpl")

  vars = {
    app_image      = var.app_image
    app_port       = var.app_port
    fargate_cpu    = var.fargate_cpu
    fargate_memory = var.fargate_memory
    aws_region     = var.aws_region
    aws_access_key = var.aws_access_key
    aws_secret_key = var.aws_secret_key
    django_secret_key = var.django_secret_key
    DJANGO_SETTINGS_MODULE = var.DJANGO_SETTINGS_MODULE
    DB_NAME = var.db_name
    DB_USER = var.db_user
    DB_PASSWORD = var.db_password
    DB_PORT = var.db_port
    RDS_HOSTNAME = aws_db_instance.production.address
    mercadopago_app_id = var.mercadopago_app_id
    mercadopago_secret_key = var.mercadopago_secret_key
    SSH_PUBLIC_KEY = var.SSH_PUBLIC_KEY
    USER_PASS = var.USER_PASS

  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"

  assume_role_policy = <<EOF
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Action":"sts:AssumeRole",
         "Principal":{
            "Service":"ecs-tasks.amazonaws.com"
         },
         "Effect":"Allow",
         "Sid":""
      }
   ]
}
EOF
}

resource "aws_iam_policy" "policy" {
  name        = "ecs-policy"
  description = "A test policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": [
      "ecs:Describe*"
    ],
    "Effect": "Allow",
    "Resource": "*"
  }]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"  #aws_iam_policy.policy.arn
}


resource "aws_ecs_task_definition" "app" {
  family                   = "cb-app-task"
  container_definitions    = data.template_file.cb_app.rendered
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory

  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  
}


resource "aws_ecs_service" "main" {
  name            = "cb-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"
  force_new_deployment = true

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = aws_subnet.private.*.id
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.app.id
    container_name   = "nginx-api"
    container_port   = var.app_port
  }

  depends_on = [aws_alb_listener.front_end, aws_iam_role_policy_attachment.ecs_task_execution_role]
}

