#!/bin/bash
if [[ $# -ne 1 ]]
then
  echo "Usage: $0 <environment>"
  echo "Example $0 dev"
  exit 1
fi
terraform init -reconfigure -backend-config=backend_config/${1}.tfvars
terraform fmt --recursive
terraform plan -var-file=env_vars/${1}.tfvars -out=build.plan
if [[ $? -eq 0 ]]
then
    terraform apply build.plan
    rm -f build.plan
else
    echo "ERROR: Unable to proceed due to plan failure"
fi