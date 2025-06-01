output "badge_url" {
  value       = aws_codebuild_project.feedback_app.badge_url
  description = "Badge URL for the CodeBuild project"
}

output "feedback_app_registry_id" {
  value       = aws_ecr_repository.feedback_app.id
  description = "The registry ID where the repository was created"
}

output "feedback_app_repository_url" {
  value       = aws_ecr_repository.feedback_app.repository_url
  description = "The URL of the repository (in the form aws_account_id.dkr.ecr.region.amazonaws.com/repositoryName)."
}

output "feedback_app_repository_arn" {
  value       = aws_ecr_repository.feedback_app.arn
  description = "Full ARN of the repository"
}

output "feedback_app_scanned_registry_id" {
  value       = aws_ecr_repository.feedback_app_scanned.id
  description = "The registry ID where the repository was created"
}

output "feedback_app_scanned_repository_url" {
  value       = aws_ecr_repository.feedback_app_scanned.repository_url
  description = "The URL of the repository (in the form aws_account_id.dkr.ecr.region.amazonaws.com/repositoryName)."
}

output "feedback_app_scanned_repository_arn" {
  value       = aws_ecr_repository.feedback_app_scanned.arn
  description = "Full ARN of the repository"
}

