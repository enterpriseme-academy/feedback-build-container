resource "aws_codebuild_project" "feedback_app" {
  name          = "feedback-app-build"
  description   = "Builds feedback app Docker container"
  service_role  = aws_iam_role.codebuild_role.arn
  badge_enabled = true

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = "eu-west-1"
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.feedback_app.name
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/enterpriseme-academy/feedback-app.git"
    git_clone_depth = 1
    buildspec       = "buildspec.yml"
  }
}

# CodeBuild Project for copying scanned images
resource "aws_codebuild_project" "copy_scanned_image" {
  name          = "copy-scanned-image"
  description   = "Copies scanned images to the target repository"
  service_role  = aws_iam_role.codebuild_role.arn
  badge_enabled = true

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = "eu-west-1"
    }

    environment_variable {
      name  = "TARGET_REPOSITORY"
      value = aws_ecr_repository.feedback_app_scanned.name
    }

    environment_variable {
      name  = "SOURCE_REPOSITORY"
      value = aws_ecr_repository.feedback_app.name
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/enterpriseme-academy/feedback-build-container.git"
    git_clone_depth = 1
    buildspec       = "buildspec_promote_image.yaml"
  }
}

resource "aws_iam_role" "codebuild_role" {
  name = "feedback-app-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "feedback-app-codebuild-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Resource = ["*"]
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

