[![Python lambda tests](https://github.com/enterpriseme-academy/feedback-build-container/actions/workflows/main.yml/badge.svg)](https://github.com/enterpriseme-academy/feedback-build-container/actions/workflows/main.yml)

# feedback-build-container

Infrastructure to build docker container and store it in ECR. Every image stored in ECR will trigger security scan.
Lambda function validate_scanned_image will check scan results and if no Critical or High vulnarabilities are found then CodeBuild Project `copy-scanned-image` is started which will copy container from `feedback_app` ECR repo to `feedback_app_scanned` ECR repo.

