#!/bin/bash
# ==============================================================================
# check_env.sh
# ------------------------------------------------------------------------------
# Purpose:
#   - Validate that all required CLI tools are available in PATH
#   - Verify presence of GCP service account credentials
#   - Confirm gcloud authentication using credentials.json
#
# ==============================================================================

echo "NOTE: Validating that required commands are available in PATH."

# ------------------------------------------------------------------------------
# Required Commands
# ------------------------------------------------------------------------------

# List of required CLI tools for the GCP Xubuntu build.
commands=("gcloud" "terraform" "packer" "jq")

# Track whether all commands are present.
all_found=true

# Iterate through each required command and validate availability.
for cmd in "${commands[@]}"; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "ERROR: $cmd is not found in the current PATH."
    all_found=false
  else
    echo "NOTE: $cmd is found in the current PATH."
  fi
done

# Abort if any required commands are missing.
if [ "$all_found" = true ]; then
  echo "NOTE: All required commands are available."
else
  echo "ERROR: One or more required commands are missing."
  exit 1
fi

# ------------------------------------------------------------------------------
# Credentials Validation
# ------------------------------------------------------------------------------

echo "NOTE: Validating credentials.json and testing gcloud authentication."

# Ensure the GCP service account key exists.
if [[ ! -f "./credentials.json" ]]; then
  echo "ERROR: The file './credentials.json' does not exist." >&2
  exit 1
fi

# Authenticate gcloud using the service account key.
gcloud auth activate-service-account --key-file="./credentials.json"

# Export Application Default Credentials for dependent tools.
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/credentials.json"

./api_setup.sh