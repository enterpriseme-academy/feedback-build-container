from aws_lambda_powertools import Logger
import boto3
import json
import os

# Initialize logger
logger = Logger(
    service="validate-scanned-image",
    level="INFO",                      # Log level (INFO, DEBUG, WARNING, ERROR, CRITICAL)
    sample_rate=1.0,                   # Sampling rate for debug logs (1.0 = log everything)
    correlation_id_path="event.detail.image-tags[0]"  # Path to correlation ID in the event
)

@logger.inject_lambda_context    # Automatically log Lambda context info
def handler(event, context):
    try:
        ecr = boto3.client('ecr')
        account_id = context.invoked_function_arn.split(":")[4]
        region = os.environ['AWS_DEFAULT_REGION']
        source_repo = os.environ['SOURCE_REPOSITORY']
        target_repo = os.environ['TARGET_REPOSITORY']
        project_name = os.environ['CODEBUILD_PROJECT_NAME']

        # Log input event
        logger.info("Processing ECR scan event", extra={
            "source_repo": source_repo,
            "target_repo": target_repo,
            "account_id": account_id,
            "region": region
        })
        
        # Get image details from event
        detail = event['detail']
        image_tag = detail['image-tags'][0]
        
        # Log scan findings request
        logger.debug("Requesting scan findings", extra={
            "repository": source_repo,
            "image_tag": image_tag
        })
        
        response = ecr.describe_image_scan_findings(
            repositoryName=source_repo,
            imageId={'imageTag': image_tag}
        )
        
        findings = response['imageScanFindings']
        
        # Log findings summary
        logger.info("Scan findings retrieved", extra={
            "findings_count": len(findings.get('findings', [])),
            "scan_status": findings.get('imageScanStatus', {}).get('status')
        })
        
        has_critical_or_high = any(
            finding['severity'] in ['CRITICAL', 'HIGH']
            for finding in findings.get('findings', [])
        )
        
        if not has_critical_or_high:
            try:
                codebuild = boto3.client('codebuild')
                logger.info("Starting CodeBuild project", extra={
                    "project_name": project_name,
                    "image_tag": image_tag
                })
                
                codebuild.start_build(
                    projectName=project_name,
                    environmentVariablesOverride=[
                        {
                            'name': 'IMAGE_REPO_NAME_SOURCE',
                            'value': source_repo,
                            'type': 'PLAINTEXT'
                        },
                        {
                            'name': 'IMAGE_REPO_NAME_TARGET',
                            'value': target_repo,
                            'type': 'PLAINTEXT'
                        },
                        {
                            'name': 'IMAGE_TAG',
                            'value': image_tag,
                            'type': 'PLAINTEXT'
                        },
                        {
                            'name': 'AWS_DEFAULT_REGION',
                            'value': region,
                            'type': 'PLAINTEXT'
                        },
                        {
                            'name': 'AWS_ACCOUNT_ID',
                            'value': account_id,
                            'type': 'PLAINTEXT'
                        }
                    ]
                )
                logger.info("CodeBuild project triggered successfully")
                    
            except Exception as e:
                logger.exception("Error executing CodeBuild project")
                raise e
        else:
            logger.warning("Image has critical or high vulnerabilities", extra={
                "source_repo": source_repo,
                "image_tag": image_tag
            })

    except Exception as e:
        logger.exception("Unhandled exception in handler")
        raise e