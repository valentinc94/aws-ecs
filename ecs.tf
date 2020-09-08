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
            "Service":"ec2.amazonaws.com"
         },
         "Effect":"Allow",
         "Sid":""
      }
   ]
}
EOF
}

resource "aws_iam_policy" "policy" {
  name        = "test-policy"
  description = "A test policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": [
      "ec2:Describe*"
    ],
    "Effect": "Allow",
    "Resource": "*"
  }]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.policy.arn
}


resource "aws_ecs_task_definition" "app" {
  family                   = "cb-app-task"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  container_definitions    = data.template_file.cb_app.rendered

  proxy_configuration {
    type           = "APPMESH"
    container_name = "cb-app"
    properties = {
      AppPorts         = "8080"
      EgressIgnoredIPs = "169.254.170.2,169.254.169.254"
      IgnoredUID       = "1337"
      ProxyEgressPort  = 15001
      ProxyIngressPort = 15000
    }
  }

}

resource "aws_ecs_service" "main" {
  name            = "cb-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = aws_subnet.private.*.id
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.app.id
    container_name   = "cb-app"
    container_port   = var.app_port
  }

  depends_on = [aws_alb_listener.front_end, aws_iam_role_policy_attachment.ecs_task_execution_role]
}

