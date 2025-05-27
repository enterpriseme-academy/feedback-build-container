import pytest
from unittest.mock import Mock, patch
from index import handler, logger

@pytest.fixture
def mock_context():
    context = Mock()
    context.invoked_function_arn = "arn:aws:lambda:eu-west-1:123456789012:function:test-function"
    return context

@pytest.fixture
def mock_event():
    return {
        "detail": {
            "image-tags": ["latest"]
        }
    }

@pytest.fixture
def mock_environment(monkeypatch):
    env_vars = {
        "AWS_DEFAULT_REGION": "eu-west-1",
        "SOURCE_REPOSITORY": "feedback-app",
        "TARGET_REPOSITORY": "feedback-app-scanned",
        "CODEBUILD_PROJECT_NAME": "copy-scanned-image"
    }
    for key, value in env_vars.items():
        monkeypatch.setenv(key, value)
    return env_vars

def test_handler_no_vulnerabilities(mock_event, mock_context, mock_environment):
    with patch('boto3.client') as mock_boto3:
        # Mock ECR client responses
        mock_ecr = Mock()
        mock_ecr.describe_image_scan_findings.return_value = {
            'imageScanFindings': {
                'findings': [],
                'imageScanStatus': {'status': 'COMPLETE'}
            }
        }
        
        # Mock CodeBuild client
        mock_codebuild = Mock()
        mock_codebuild.start_build.return_value = {'build': {'id': 'test-build-id'}}
        
        # Configure boto3 to return our mocked clients
        mock_boto3.side_effect = lambda service: {
            'ecr': mock_ecr,
            'codebuild': mock_codebuild
        }[service]
        
        # Execute handler
        handler(mock_event, mock_context)
        
        # Verify ECR calls
        mock_ecr.describe_image_scan_findings.assert_called_once_with(
            repositoryName='feedback-app',
            imageId={'imageTag': 'latest'}
        )
        
        # Verify CodeBuild calls
        mock_codebuild.start_build.assert_called_once()

def test_handler_with_critical_vulnerabilities(mock_event, mock_context, mock_environment):
    with patch('boto3.client') as mock_boto3:
        # Mock ECR client with critical vulnerability
        mock_ecr = Mock()
        mock_ecr.describe_image_scan_findings.return_value = {
            'imageScanFindings': {
                'findings': [{
                    'severity': 'CRITICAL',
                    'name': 'TEST-VULN-1'
                }],
                'imageScanStatus': {'status': 'COMPLETE'}
            }
        }
        
        mock_boto3.return_value = mock_ecr
        
        # Execute handler
        handler(mock_event, mock_context)
        
        # Verify ECR calls
        mock_ecr.describe_image_scan_findings.assert_called_once()
        
        # Verify CodeBuild was not called
        mock_ecr.start_build.assert_not_called()

def test_handler_error_handling(mock_event, mock_context, mock_environment):
    with patch('boto3.client') as mock_boto3:
        # Mock ECR client that raises an exception
        mock_ecr = Mock()
        mock_ecr.describe_image_scan_findings.side_effect = Exception("Test error")
        
        mock_boto3.return_value = mock_ecr
        
        # Execute handler and expect exception
        with pytest.raises(Exception) as exc_info:
            handler(mock_event, mock_context)
        
        assert str(exc_info.value) == "Test error"

def test_environment_variables(mock_event, mock_context):
    with patch('boto3.client') as mock_boto3, \
         pytest.raises(KeyError) as exc_info:
        # Don't set environment variables
        handler(mock_event, mock_context)
    
    # Verify that handler raises KeyError for missing env vars
    assert "AWS_DEFAULT_REGION" in str(exc_info.value)