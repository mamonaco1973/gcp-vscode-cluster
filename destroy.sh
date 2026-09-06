#!/bin/bash
# ==============================================================================
# Destroy Pipeline Script: Mini-AD + VS Code Cluster on GCP
# ------------------------------------------------------------------------------
# Purpose:
#   - Tear down infrastructure in reverse order
#   - Destroy cluster, delete images, destroy servers, destroy directory
#   - Remove residual GCP resources after cleanup
# ==============================================================================

set -e  # Exit immediately on unhandled command failure


# ==============================================================================
# Phase 1: VS Code Cluster Teardown
# ------------------------------------------------------------------------------
# Purpose:
#   - Destroy cluster using latest VS Code image name
# ==============================================================================

vscode_image=$(gcloud compute images list \
  --filter="name~'^vscode-image' AND family=vscode-images" \
  --sort-by="~creationTimestamp" \
  --limit=1 \
  --format="value(name)")

if [[ -z "$vscode_image" ]]; then
  echo "ERROR: No latest image found for 'vscode-image' in family 'vscode-images'."
  exit 1
fi

cd 04-cluster

terraform init
terraform destroy \
  -var="vscode_image_name=$vscode_image" \
  -auto-approve

cd ..

# ==============================================================================
# Phase 2: Custom Image Cleanup
# ------------------------------------------------------------------------------
# Purpose:
#   - Delete Packer-built images with vscode prefix (best-effort)
# ==============================================================================

echo "NOTE: Fetching images starting with 'vscode' to delete..."

image_list=$(gcloud compute images list \
  --format="value(name)" \
  --filter="name~'^(vscode)'")

if [ -z "$image_list" ]; then
  echo "NOTE: No images found starting with 'vscode'. Nothing to delete."
else
  echo "NOTE: Deleting images..."
  for image in $image_list; do
    echo "NOTE: Deleting image: $image"
    gcloud compute images delete "$image" --quiet \
      || echo "WARNING: Failed to delete image: $image"
  done
fi


# ==============================================================================
# Phase 3: Server Teardown
# ------------------------------------------------------------------------------
# Purpose:
#   - Destroy Windows and Linux client VMs connected to Active Directory
# ==============================================================================

cd 02-servers

terraform init
terraform destroy -auto-approve

cd ..


# ==============================================================================
# Phase 4: Active Directory Teardown
# ------------------------------------------------------------------------------
# Purpose:
#   - Destroy Samba-based Active Directory resources
# ==============================================================================

cd 01-directory

terraform init
terraform destroy -auto-approve

cd ..