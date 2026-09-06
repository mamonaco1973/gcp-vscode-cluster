# ==============================================================================
# tls.tf
# ------------------------------------------------------------------------------
# Purpose:
#   - Generate a self-signed TLS certificate and upload it to Compute Engine
#   - Let the load balancer terminate HTTPS with no registered domain and no
#     public certificate authority
#
# Why HTTPS is required rather than optional:
#   Over plain HTTP, carrier and ISP security products inspect page content
#   inline. In practice they classify an unbranded credential form on a bare
#   IP address as phishing and block it outright, and some mobile carriers
#   also mangle the WebSocket Upgrade handshake that code-server depends on.
#   TLS ends both behaviours -- the middlebox can no longer read or rewrite
#   the stream.
#
# Why the certificate names an IP and not a hostname:
#   AWS hands every ALB a *.elb.amazonaws.com name that a certificate can be
#   issued for. Google gives a global forwarding rule an IP address and
#   nothing else, so the IP itself goes in the SAN. Browsers honour IP SANs,
#   which keeps the warning down to the untrusted issuer alone rather than
#   issuer plus hostname mismatch.
#
# Trade-off:
#   Browsers do not trust a self-signed issuer, so users get an interstitial
#   and must choose "Advanced -> Proceed". Worse, clicking through is not
#   enough for full function: without a trusted certificate there is no
#   secure context, Chrome refuses to register a service worker, and every
#   VS Code webview renders blank. Import the certificate on the client to
#   fix that -- see the README.
#
#   To remove the warning entirely, put a real domain in front of the LB and
#   swap this file for a google_compute_managed_ssl_certificate.
# ==============================================================================


# ==============================================================================
# Provider Requirement: TLS
# ------------------------------------------------------------------------------
# The tls provider generates the key and certificate locally during apply, so
# apply.sh gains no dependency on openssl being installed.
# ==============================================================================

terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}


# ==============================================================================
# Private Key
# ==============================================================================

resource "tls_private_key" "lb" {
  algorithm = "RSA"
  rsa_bits  = 2048
}


# ==============================================================================
# Self-Signed Certificate
# ------------------------------------------------------------------------------
# The global address is reserved as its own resource, so its IP is known
# before anything is attached to it. That is what makes this ordering work:
#   global_address -> tls_self_signed_cert -> ssl_certificate -> https_proxy
# ==============================================================================

resource "tls_self_signed_cert" "lb" {
  private_key_pem = tls_private_key.lb.private_key_pem

  subject {
    common_name  = google_compute_global_address.lb_ip.address
    organization = "VS Code Cluster Lab"
  }

  # Browsers ignore common_name on its own; the SAN is what actually matches.
  ip_addresses = [google_compute_global_address.lb_ip.address]

  validity_period_hours = 8760 # One year; lab certificate, not renewed.

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}


# ==============================================================================
# Upload to Compute Engine
# ------------------------------------------------------------------------------
# GCP SSL certificates are immutable, and one attached to a live proxy cannot
# be deleted. Without name_prefix + create_before_destroy, any change to the
# certificate deadlocks the apply: Terraform tries to destroy a certificate
# the target proxy still references. The prefix lets it mint the replacement,
# repoint the proxy, then drop the old one.
# ==============================================================================

resource "google_compute_ssl_certificate" "lb" {
  name_prefix = "vscode-cert-"
  private_key = tls_private_key.lb.private_key_pem
  certificate = tls_self_signed_cert.lb.cert_pem

  lifecycle {
    create_before_destroy = true
  }
}


# ==============================================================================
# Outputs
# ==============================================================================

output "vscode_url" {
  description = "HTTPS endpoint for the VS Code cluster"
  value       = "https://${google_compute_global_address.lb_ip.address}"
}

# Emitted so the certificate can be added to a workstation trust store
# without digging it out of the browser. Trusting it is required for VS Code
# webviews. Public half only; the private key stays in state.
output "vscode_certificate_pem" {
  description = "Self-signed certificate to trust on client machines"
  value       = tls_self_signed_cert.lb.cert_pem
}
