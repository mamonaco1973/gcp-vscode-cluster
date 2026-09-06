#!/bin/bash
# ==============================================================================
# validate.sh - RStudio Quick Start Validation (GCP)
# ------------------------------------------------------------------------------
# Purpose:
#   - Print external IPs for NFS gateway and Windows AD host
#   - Fetch global LB IP and verify /auth-sign-in returns HTTP 200
#   - Scope instance lookups to VPC: rstudio-vpc
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
VPC_NAME="rstudio-vpc"
NFS_PREFIX="nfs-gateway"
WIN_PREFIX="win-ad"
LB_NAME="rstudio-lb-ip"

CHECK_INTERVAL=60
MAX_RETRIES=30

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
gcloud_trim() {
  xargs 2>/dev/null || true
}

get_instance_nat_ip_by_prefix_and_vpc() {
  local prefix="$1"
  local vpc="$2"

  gcloud compute instances list \
    --filter="name~'^${prefix}.*' AND networkInterfaces.network:${vpc}" \
    --format="value(networkInterfaces[0].accessConfigs[0].natIP)" \
    --limit=1 2>/dev/null | gcloud_trim
}

get_global_address_ip() {
  local name="$1"

  gcloud compute addresses describe "${name}" \
    --global \
    --format="value(address)" 2>/dev/null | gcloud_trim
}

get_http_code() {
  local url="$1"
  curl -o /dev/null -s -w "%{http_code}" "${url}" || true
}

# ------------------------------------------------------------------------------
# Lookups (Scoped to VPC)
# ------------------------------------------------------------------------------
NFS_IP="$(get_instance_nat_ip_by_prefix_and_vpc "${NFS_PREFIX}" "${VPC_NAME}")"
WIN_IP="$(get_instance_nat_ip_by_prefix_and_vpc "${WIN_PREFIX}" "${VPC_NAME}")"

RSTUDIO_LB_IP="$(get_global_address_ip "${LB_NAME}")"
if [[ -z "${RSTUDIO_LB_IP}" ]]; then
  echo "ERROR: Failed to retrieve the load balancer IP address. Exiting."
  exit 1
fi

# ------------------------------------------------------------------------------
# Wait for Load Balancer Availability
# ------------------------------------------------------------------------------
URL="http://${RSTUDIO_LB_IP}/auth-sign-in"

echo "NOTE: Waiting for load balancer to return HTTP 200 on /auth-sign-in..."

for ((i = 1; i <= MAX_RETRIES; i++)); do
  HTTP_CODE="$(get_http_code "${URL}")"

  if [[ "${HTTP_CODE}" == "200" ]]; then
    break
  fi

  echo "NOTE: Retry ${i}/${MAX_RETRIES}: HTTP ${HTTP_CODE}. Retrying..."
  sleep "${CHECK_INTERVAL}"

  if [[ "${i}" -eq "${MAX_RETRIES}" ]]; then
    echo "ERROR: Timeout reached. Load balancer did not become active."
    exit 1
  fi
done

# ------------------------------------------------------------------------------
# Quick Start Output
# ------------------------------------------------------------------------------
echo ""
echo "============================================================================"
echo "RStudio Quick Start - Validation Output (GCP)"
echo "============================================================================"
echo ""

printf "%-28s %s\n" "NOTE: NFS Gateway Host:" "${NFS_IP:-<not found>}"
printf "%-28s %s\n" "NOTE: Windows RDP Host:" "${WIN_IP:-<not found>}"

echo ""

printf "%-28s %s\n" "NOTE: RStudio URL:"      "http://${RSTUDIO_LB_IP}"

echo ""

