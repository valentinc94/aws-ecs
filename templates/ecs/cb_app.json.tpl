[
  {
    "name": "cb-app",
    "image": "cb-app:latest",
    "cpu": 10,
    "memory": 512,
    "networkMode": "awsvpc",
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/cb-app",
          "awslogs-region": "${aws_region}",
          "awslogs-stream-prefix": "ecs"
        }
    },
    "environment": [
    {
      "name": "DJANGO_SECRET_KEY",
      "value": "21+p)jxz_v846@ub2351@z^fv08hsi125bfd3n!f@ytt21$efh"
    }
    ],
    "portMappings": [
      {
        "containerPort": 8000,
        "hostPort": 8000,
        "protocol": "tcp"
      }
    ]
  },
  {
    "name": "nginx-api",
    "image": "${app_image}",
    "cpu": 10,
    "memory": 128,
    "networkMode": "awsvpc",
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/nginx-api",
          "awslogs-region": "${aws_region}",
          "awslogs-stream-prefix": "nginx-log-stream"
        }
    },
    "portMappings": [
      {
        "containerPort": ${app_port},
        "hostPort": ${app_port}
      }
    ],
    "dependsOn": [
      {
        "containerName": "cb-app",
        "condition": "START"
      }
    ]
  }
]