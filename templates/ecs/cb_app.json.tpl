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
      "value": "${django_secret_key}"
    },
    {
      "name": "AWS_ACCESS_KEY_ID",
      "value": "${aws_access_key}"
    },
    {
      "name": "AWS_SECRET_ACCESS_KEY",
      "value": "${aws_secret_key}"
    },
    {
      "name": "DJANGO_SETTINGS_MODULE",
      "value": "${DJANGO_SETTINGS_MODULE}"
    },
    {
      "name": "RDS_HOSTNAME",
      "value": "${rds_hostname}"
    },
    {
      "name": "DB_NAME",
      "value": "${DB_NAME}"
    },
    {
      "name": "DB_USER",
      "value": "${DB_USER}"
    },
    {
      "name": "DB_PASSWORD",
      "value": "${DB_PASSWORD}"
    },
    {
      "name": "DB_PORT",
      "value": "${DB_PORT}"
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