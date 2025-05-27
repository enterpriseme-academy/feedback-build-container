# Create zip file for Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_code/index.py"
  output_path = "${path.module}/lambda_code/lambda_function.zip"
}

# Update Lambda function resource to use the zip file
resource "aws_lambda_function" "copy_scanned_image" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  function_name    = "validate-scanned-image"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  timeout          = 300
  layers           = ["arn:aws:lambda:eu-west-1:017000801446:layer:AWSLambdaPowertoolsPythonV2:40"]

  environment {
    variables = {
      TARGET_REPOSITORY      = aws_ecr_repository.feedback_app_scanned.name
      SOURCE_REPOSITORY      = aws_ecr_repository.feedback_app.name
      CODEBUILD_PROJECT_NAME = aws_codebuild_project.copy_scanned_image.name
      AWS_DEFAULT_REGION     = data.aws_region.current.name
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "copy-scanned-image-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "copy-scanned-image-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:GetLifecyclePolicy",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:ListTagsForResource",
          "ecr:DescribeImageScanFindings",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}

# EventBridge rule
resource "aws_cloudwatch_event_rule" "scan_complete" {
  name        = "ecr-scan-complete"
  description = "Capture ECR scan complete events"

  event_pattern = jsonencode({
    source      = ["aws.ecr"]
    detail-type = ["ECR Image Scan"]
    detail = {
      repository-name = [aws_ecr_repository.feedback_app.name]
      scan-status     = ["COMPLETE"]
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.scan_complete.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.copy_scanned_image.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.copy_scanned_image.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scan_complete.arn
}