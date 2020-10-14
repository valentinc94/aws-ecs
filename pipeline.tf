
resource "aws_ecr_repository" "atua" {
  name                 = "atua-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "nginx" {
  name                 = "nginx-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository_policy" "nginx-policy" {
  repository = aws_ecr_repository.nginx.name

  policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "new policy",
            "Effect": "Allow",
            "Principal": "*",
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:DescribeRepositories",
                "ecr:GetRepositoryPolicy",
                "ecr:ListImages",
                "ecr:DeleteRepository",
                "ecr:BatchDeleteImage",
                "ecr:SetRepositoryPolicy",
                "ecr:DeleteRepositoryPolicy"
            ]
        }
    ]
}
EOF
}


resource "aws_ecr_repository_policy" "foopolicy" {
  repository = aws_ecr_repository.atua.name

  policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "new policy",
            "Effect": "Allow",
            "Principal": "*",
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:DescribeRepositories",
                "ecr:GetRepositoryPolicy",
                "ecr:ListImages",
                "ecr:DeleteRepository",
                "ecr:BatchDeleteImage",
                "ecr:SetRepositoryPolicy",
                "ecr:DeleteRepositoryPolicy"
            ]
        }
    ]
}
EOF
}

resource "aws_kms_key" "codepipeline" {
  description             = "KMS key 1"
  deletion_window_in_days = 10
}


resource "aws_iam_role" "pipeline" {
  name = "pipeline"
  # Only codebuild.amazonaws.com can assume this role
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

## Build rol

resource "aws_iam_role" "build" {
  name = "codebuild"
  # Only codebuild.amazonaws.com can assume this role
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild-policy" {
  name = "codebuild-policy"
  role = aws_iam_role.build.id
  policy = data.aws_iam_policy_document.codebuild-policy-doc.json
}

resource "aws_iam_role_policy_attachment" "build" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  role       = aws_iam_role.build.id
}

data "aws_iam_policy_document" "codebuild-policy-doc" {
  version = "2012-10-17"

  # Write CloudWatch logs
  statement {
    effect = "Allow"
    resources = [
      aws_cloudwatch_log_group.cb_log_group.arn
    ]
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
  }

  # Encrypt/decrypt data using KMS key
  statement {
    effect = "Allow"
    resources = [
      aws_kms_key.codepipeline.arn
    ]
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
    ]
  }

  # Read/write from artifacts S3 bucket
  statement {
    effect = "Allow"
    resources = [
      "${aws_s3_bucket.codepipeline-bucket.arn}/*"
    ]
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
    ]
  }

  # Read/write to ECR (see https://github.com/aws/aws-toolkit-azure-devops/issues/311#issuecomment-623871181)
  statement {
    effect = "Allow"
    resources = [
      aws_ecr_repository.atua.arn,
      aws_ecr_repository.nginx.arn,
    ]
    actions = [
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
  }

  # Log into ECR (this can only have * as a resource)
  statement {
    effect = "Allow"
    resources = [
      "*"
    ]
    actions = [
      "ecr:GetAuthorizationToken",
    ]
  }
}


resource "aws_s3_bucket" "codepipeline-bucket" {
  bucket = "atua-static"
  acl    = "public-read-write"
  force_destroy = true

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}


############ Polytics for codepipeline #########

resource "aws_iam_role_policy" "codepipeline-policy" {
  name = "codepipeline-policy"
  role = aws_iam_role.pipeline.id
  policy = data.aws_iam_policy_document.codepipeline-policy-doc.json
}

data "aws_iam_policy_document" "codepipeline-policy-doc" {
  version = "2012-10-17"

  # Pass this role on
  statement {
    effect = "Allow"
    resources = ["*"]
    actions = [
      "iam:PassRole"
    ]
    condition {
      test = "StringEqualsIfExists"
      variable = "iam:PassedToService"
      values = ["ecs-tasks.amazonaws.com"]
    }
  }

//  statement {
//    effect = "Allow"
//    resources = "*"
//    actions = [
//      "codedeploy:CreateDeployment",
//      "codedeploy:GetApplication",
//      "codedeploy:GetApplicationRevision",
//      "codedeploy:GetDeployment",
//      "codedeploy:GetDeploymentConfig",
//      "codedeploy:RegisterApplicationRevision"
//    ]
//  }

  # ECS stuff (TODO restrict this)
  statement {
    effect = "Allow"
    resources = [
//      aws_ecs_cluster.api-cluster.arn,
//      aws_ecs_service.api-service.id,
//      aws_ecs_task_definition.api-task.arn,
      "*",
    ]
    actions = [
      "ecs:*"
    ]
  }

  # Decrypt data using KMS key
  statement {
    effect = "Allow"
    resources = [
      aws_kms_key.codepipeline.arn
    ]
    actions = [
      "kms:Decrypt",
    ]
  }

  # Read stuff from S3
  statement {
    effect = "Allow"
    resources = [
      "${aws_s3_bucket.codepipeline-bucket.arn}/*"
    ]
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObject",
    ]
  }

  # Get/start builds
  statement {
    effect = "Allow"
    resources = ["*"]
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]
  }

  # Describe ECR images TODO is this required?
  statement {
    effect = "Allow"
    actions = [
      "ecr:DescribeImages"
    ]
    resources = [
      aws_ecr_repository.atua.arn,
      aws_ecr_repository.nginx.arn,
    ]
  }
}


###  end ########

resource "aws_codepipeline" "api" {
  name     = "api-pipeline"
  role_arn = aws_iam_role.pipeline.arn

  
  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.codepipeline-bucket.bucket
  }

  stage {
    name = "Source"

    action {
      category = "Source"
      name             = "Source"
      namespace        = "SourceVariables"
      output_artifacts = ["SourceArtifact"]
      owner            = "ThirdParty"
      provider         = "GitHub"
      region           = var.aws_region
      run_order        = "1"
      version          = "1"

      configuration = {
        OAuthToken           = var.github_token
        Branch               = var.branch
        Owner                = "BuscameLids"
        PollForSourceChanges = "true"
        Repo                 = "atua-back"
      }
    }
  }

  stage {
    name = "Build"

    action {
      category = "Build"
      input_artifacts  = ["SourceArtifact"]
      name             = "Build"
      namespace        = "BuildVariables"
      output_artifacts = ["imagedefinitions"]
      owner            = "AWS"
      provider         = "CodeBuild"
      region           = var.aws_region
      run_order        = "1"
      version          = "1"

      configuration = {
        ProjectName = "api"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      category = "Deploy"

      input_artifacts = ["imagedefinitions"]
      name            = "Deploy"
      namespace       = "DeployVariables"
      owner           = "AWS"
      provider        = "ECS"
      region          = var.aws_region
      run_order       = "1"
      version         = "1"

      configuration = {
        ClusterName = aws_ecs_cluster.main.name
        ServiceName = aws_ecs_service.main.name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}

resource "aws_codepipeline_webhook" "api" {
  authentication = "GITHUB_HMAC"

  authentication_configuration {
    secret_token = var.github_token
  }

  filter {
    json_path    = "$.ref"
    match_equals = "refs/heads/{Branch}"
  }

  name            = "api-codepipeline-webhook"
  target_action   = "Source"
  target_pipeline = aws_codepipeline.api.name
}


#################### Code build ###################

#### locals

resource "aws_codebuild_project" "api" {
  name           = "api"
  queued_timeout = "60"
  service_role   = aws_iam_role.build.arn
  badge_enabled = "false"
  build_timeout = "15"
  encryption_key = aws_kms_key.codepipeline.arn

  artifacts {
    name                   = "api"
    type                   = "CODEPIPELINE"
    encryption_disabled    = "false"
    override_artifact_name = "false"
    packaging              = "NONE"
  }

  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = "true"

    environment_variable {
      name = "REGION"
      value = var.aws_region
    }
    environment_variable {
      name = "REPOSITORY_DOMAIN"
      value = replace(aws_ecr_repository.atua.repository_url, "//?${aws_ecr_repository.atua.name}/?/", "")
    }
    environment_variable {
      name = "REPOSITORY_URI"
      value = aws_ecr_repository.atua.repository_url
    }
    environment_variable {
      name = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.atua.name
    }
    environment_variable {
      name = "AWS_REGION"
      value = var.aws_region
    }
    environment_variable {
      name = "AWS_ACCOUNT_ID"
      value = var.aws_account_id
    }
    environment_variable {
      name = "DJANGO_SECRET_KEY"
      value = var.django_secret_key
    }
    environment_variable {
      name = "DB_HOST"
      value = aws_db_instance.production.address
    }
    environment_variable {
      name = "DB_NAME"
      value = var.db_name
    }
    environment_variable {
      name = "DB_USER"
      value = var.db_user
    }
    environment_variable {
      name = "DB_PASSWORD"
      value = var.db_password
    }
    environment_variable {
      name = "DB_PORT"
      value = var.db_port
    }
    environment_variable {
      name = "DJANGO_SETTINGS_MODULE"
      value = var.DJANGO_SETTINGS_MODULE
    }
    environment_variable {
      name = "IMAGE_TAG"
      value = var.image
    }
    environment_variable {
      name = "REPOSITORY_NGINX"
      value = aws_ecr_repository.nginx.repository_url
    }
    environment_variable {
      name = "SSH_PUBLIC_KEY"
      value = var.SSH_PUBLIC_KEY
    }

    environment_variable {
      name = "USER_PASS"
      value = var.USER_PASS
    }
    
  }

  source {
    type                = "CODEPIPELINE"
    git_clone_depth     = "0"
    insecure_ssl        = "false"
    report_build_status = "false"
  }

  cache {
    type = "NO_CACHE"
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
      group_name = aws_cloudwatch_log_group.cb_log_group.name
      stream_name = "api"
    }

    s3_logs {
      status = "DISABLED"
      encryption_disabled = "false"
    }
  }
}

############################    deploy 

resource "aws_iam_role" "codedeploy" {
  name               = "atua-codedeploy"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

// AWS IAM Role Policy in format JSON for codeploy
data "aws_iam_policy_document" "ecs_codedeploy_role_policy" {
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ecs:DescribeServices",
      "ecs:CreateTaskSet",
      "ecs:UpdateServicePrimaryTaskSet",
      "ecs:DeleteTaskSet",
      "ecs:*",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:ModifyRule",
      "lambda:InvokeFunction",
      "cloudwatch:DescribeAlarms",
      "sns:Publish",
      "s3:GetObject",
      "s3:GetObjectMetadata",
      "s3:GetObjectVersion",
    ]
  }
}

// Aditional Role policy Iam:passROLE for execute task
data "aws_iam_policy_document" "ecs_codedeploy_role_policy_task" {
  statement {
    effect    = "Allow"
    resources = [aws_iam_role.ecs_task_execution_role.arn]

    actions = [
      "iam:PassRole",
    ]
  }
}

// ECS Codedeploy policy to execute ecs task
data "aws_iam_policy_document" "ecs_codedeploy_role_policy_task_exec" {
  statement {
    effect    = "Allow"
    resources = [aws_iam_role.ecs_task_execution_role.arn]

    actions = [
      "iam:PassRole",
    ]
  }
}

// AWS IAM Role Policy used for codedeploy
resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
  role       = aws_iam_role.codedeploy.name
}

// AWS IAM Role Policy used for ecs codedeploy
resource "aws_iam_role_policy" "ecs_codedeploy_role_policy" {
  name   = "ecs_codedeploy_role_policy"
  policy = data.aws_iam_policy_document.ecs_codedeploy_role_policy.json
  role   = aws_iam_role.codedeploy.id
}

// Attach policies for codedeploy run task, drain, etc
resource "aws_iam_role_policy" "ecs_codedeploy_role_policy_task" {
  name   = "ecs_codedeploy_role_policy_task"
  policy = data.aws_iam_policy_document.ecs_codedeploy_role_policy_task.json
  role   = aws_iam_role.codedeploy.id
}

resource "aws_iam_role_policy" "ecs_codedeploy_role_policy_task_exec" {
  name   = "ecs_codedeploy_role_policy_task_exec"
  policy = data.aws_iam_policy_document.ecs_codedeploy_role_policy_task_exec.json
  role   = aws_iam_role.codedeploy.id
}


resource "aws_codedeploy_app" "atua" {
  compute_platform = "ECS"
  name             = "atua"
}
