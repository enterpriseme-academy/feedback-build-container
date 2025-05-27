output "badge_url" {
  value       = aws_codebuild_project.feedback_app.badge_url
  description = "Badge URL for the CodeBuild project"
}