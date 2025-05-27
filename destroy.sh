#!/bin/bash
if [[ $# -ne 1 ]]
then
  echo "Usage: $0 <environment>"
  echo "Example $0 dev"
  exit 1
fi
terraform init -reconfigure -backend-config=backend_config/${1}.tfvars
terraform destroy -var-file=env_vars/${1}.tfvars 
