#!/bin/bash
# ==============================================================================
# validate.sh - VS Code Quick Start Validation (GCP)
# ------------------------------------------------------------------------------
# Purpose:
#   - Print external IPs for NFS gateway and Windows AD host
#   - Fetch global LB IP and verify /healthz returns HTTP 200 over HTTPS
#   - Export the self-signed certificate for import on client machines
#   - Scope instance lookups to VPC: vscode-vpc
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
VPC_NAME="vscode-vpc"
NFS_PREFIX="nfs-gateway"
WIN_PREFIX="win-ad"
LB_NAME="vscode-lb-ip"

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

# -k is required, not sloppy: the LB presents a self-signed certificate by
# design (see 04-cluster/tls.tf). Verification is exactly what we cannot do.
get_http_code() {
  local url="$1"
  curl -k -o /dev/null -s -w "%{http_code}" "${url}" || true
}

# ------------------------------------------------------------------------------
# Lookups (Scoped to VPC)
# ------------------------------------------------------------------------------
NFS_IP="$(get_instance_nat_ip_by_prefix_and_vpc "${NFS_PREFIX}" "${VPC_NAME}")"
WIN_IP="$(get_instance_nat_ip_by_prefix_and_vpc "${WIN_PREFIX}" "${VPC_NAME}")"

VSCODE_LB_IP="$(get_global_address_ip "${LB_NAME}")"
if [[ -z "${VSCODE_LB_IP}" ]]; then
  echo "ERROR: Failed to retrieve the load balancer IP address. Exiting."
  exit 1
fi

# ------------------------------------------------------------------------------
# Wait for Load Balancer Availability
# ------------------------------------------------------------------------------
URL="https://${VSCODE_LB_IP}/healthz"

echo "NOTE: Waiting for load balancer to return HTTP 200 on /healthz..."

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
echo "VS Code Quick Start - Validation Output (GCP)"
echo "============================================================================"
echo ""

printf "%-28s %s\n" "NOTE: NFS Gateway Host:" "${NFS_IP:-<not found>}"
printf "%-28s %s\n" "NOTE: Windows RDP Host:" "${WIN_IP:-<not found>}"

echo ""

printf "%-28s %s\n" "NOTE: VS Code URL:"      "https://${VSCODE_LB_IP}"

echo ""

# ------------------------------------------------------------------------------
# Client Certificate
# ------------------------------------------------------------------------------
# Clicking through the browser warning is enough to sign in, but not enough
# to work: without a trusted certificate there is no secure context, Chrome
# will not register a service worker, and every VS Code webview -- markdown
# preview, the settings UI, most extension panels -- renders blank. Import
# this file once per client machine.
CERT_FILE="vscode-lb.crt"

if terraform -chdir=04-cluster output -raw vscode_certificate_pem \
     > "${CERT_FILE}" 2>/dev/null && [[ -s "${CERT_FILE}" ]]; then
  printf "%-28s %s\n" "NOTE: Certificate written:" "${CERT_FILE}"
  echo ""
  echo "NOTE: Trust it before use, or webviews will render blank:"
  echo "NOTE:   Windows: certutil -addstore -user Root ${CERT_FILE}"
  echo "NOTE:   macOS:   security add-trusted-cert -d -r trustRoot ${CERT_FILE}"
else
  rm -f "${CERT_FILE}"
  echo "WARNING: Could not export the certificate from Terraform state."
fi

echo ""

