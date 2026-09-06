#!/bin/bash
# ==============================================================================
# Build Pipeline Script: Mini-AD + RStudio Cluster on GCP
# ------------------------------------------------------------------------------
# Purpose:
#   - Orchestrate multi-phase deployment using Terraform and Packer
#   - Validate environment before execution
#   - Deploy AD, servers, image, and auto-scaling cluster
# ==============================================================================

set -e  # Exit immediately on unhandled command failure


# ==============================================================================
# Phase 0: Environment Check
# ------------------------------------------------------------------------------
# Purpose:
#   - Validate required tools, variables, and configuration
# ==============================================================================

./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed. Exiting."
  exit 1
fi


# ==============================================================================
# Phase 1: Active Directory Deployment
# ------------------------------------------------------------------------------
# Purpose:
#   - Provision Samba-based Active Directory with Terraform
# ==============================================================================

cd 01-directory

terraform init                # Initialize providers and backend
terraform apply -auto-approve # Deploy AD infrastructure

if [ $? -ne 0 ]; then
  echo "ERROR: Terraform apply failed in 01-directory. Exiting."
  exit 1
fi

cd ..


# ==============================================================================
# Phase 2: Server Deployment
# ------------------------------------------------------------------------------
# Purpose:
#   - Provision Windows and Linux servers joined to AD
# ==============================================================================

cd 02-servers

terraform init                # Initialize Terraform
terraform apply -auto-approve # Deploy server resources

cd ..


# ==============================================================================
# Phase 3: RStudio Image Build
# ------------------------------------------------------------------------------
# Purpose:
#   - Build custom Compute Engine image using Packer
# ==============================================================================

project_id=$(jq -r '.project_id' "./credentials.json") # Extract project ID

gcloud auth activate-service-account --key-file="./credentials.json" > /dev/null 2> /dev/null

export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/credentials.json"

cd 03-packer

packer build \
  -var="project_id=$project_id" \
  rstudio_image.pkr.hcl

cd ..


# ==============================================================================
# Phase 4: RStudio Cluster Deployment
# ------------------------------------------------------------------------------
# Purpose:
#   - Deploy auto-scaling RStudio cluster using latest image
# ==============================================================================

rstudio_image=$(gcloud compute images list \
  --filter="name~'^rstudio-image' AND family=rstudio-images" \
  --sort-by="~creationTimestamp" \
  --limit=1 \
  --format="value(name)")

if [[ -z "$rstudio_image" ]]; then
  echo "ERROR: No latest image found in family 'rstudio-images'."
  exit 1
fi

cd 04-cluster

terraform init
terraform apply \
  -var="rstudio_image_name=$rstudio_image" \
  -auto-approve

cd ..


# ==============================================================================
# Phase 5: Validation
# ------------------------------------------------------------------------------
# Purpose:
#   - Run post-deployment validation checks
# ==============================================================================

./validate.sh