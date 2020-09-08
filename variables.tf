variable "aws_region" {
  description = "The AWS region things are created in"
  default     = "us-west-2"
}

variable "ecs_task_execution_role_name" {
  description = "ECS task execution role name"
  default = "myEcsTaskExecutionRole"
}

variable "ecs_auto_scale_role_name" {
  description = "ECS auto scale role Name"
  default = "myEcsAutoScaleRole"
}

variable "az_count" {
  description = "Number of AZs to cover in a given region"
  default     = "2"
}

variable "app_image" {
  description = "Docker image to run in the ECS cluster"
  default     = "nginx:latest"
}

variable "app_port" {
  description = "Port exposed by the docker image to redirect traffic to"
  default     = 80
}

variable "app_count" {
  description = "Number of docker containers to run"
  default     = 3
}

variable "health_check_path" {
  default = "/"
}

variable "fargate_cpu" {
  description = "Fargate instance CPU units to provision (1 vCPU = 1024 CPU units)"
  default     = "1024"
}

variable "fargate_memory" {
  description = "Fargate instance memory to provision (in MiB)"
  default     = "2048"
}

variable "api_version" {
  type        = string
  default     = "latest"
  description = "The api_version of the API"
}


variable "aws_account_id"{}
variable "aws_profile"{}
variable "aws_access_key"{}
variable "aws_secret_key"{}

variable "github_token" {
    type        = string
}
  # development
variable "branch" {
  type        = string
  description = "Branch of the GitHub repository, _e.g._ `master`"
  default     = "development"
}

# atua-back
variable "name" {
  type        = string
  description = "Name of the application"
  default = "atua-back"
}

variable "db_port" {
  type = string
}          
variable "db_name" {
  type = string
}          
variable "db_user" {
  type = string
}          
variable "db_password" {
  type = string
}      
variable "django_secret_key" {
  type = string
}

