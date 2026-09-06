# ==============================================================================
# HTTPS Load Balancer: Global IP, Backend Service, URL Map, Proxies, Rules
# ------------------------------------------------------------------------------
# Purpose:
#   - Reserve static global IP for the load balancer
#   - Terminate TLS with the self-signed certificate from tls.tf
#   - Redirect port 80 to 443 -- nothing is served in cleartext
#   - Distribute traffic to the VS Code instance group with health checks
#
# Nothing is served over plain HTTP. Cleartext is what lets ISP filters
# classify the sign-in page as phishing and lets carriers interfere with the
# WebSocket upgrade code-server depends on. See tls.tf.
# ==============================================================================


# ==============================================================================
# Static Global IP Address
# ------------------------------------------------------------------------------
# Purpose:
#   - Reserve global static IP for HTTP load balancer
#   - Keep IP stable across LB updates or recreation
# ==============================================================================

resource "google_compute_global_address" "lb_ip" {
  name = "vscode-lb-ip"
}


# ==============================================================================
# Backend Service
# ------------------------------------------------------------------------------
# Purpose:
#   - Define backend service for VS Code instance group
#   - Use health checks to gate traffic to healthy backends
# ==============================================================================

resource "google_compute_backend_service" "backend_service" {
  name          = "vscode-backend-service"
  protocol      = "HTTP"
  port_name     = "http" # Must match named port in MIG
  health_checks = [google_compute_health_check.http_health_check.self_link]

  # NOT a request timeout -- on a GCP backend service this bounds the whole
  # stream, and code-server holds one WebSocket open for the life of the
  # session. At the default the editor disconnects every few seconds.
  timeout_sec           = 86400
  load_balancing_scheme = "EXTERNAL"

  # Mandatory, not an optimization: a user's code-server process runs on one
  # node only, so every request has to come back to the same node.
  session_affinity        = "GENERATED_COOKIE"
  affinity_cookie_ttl_sec = 86400 # 1 day

  backend {
    group          = google_compute_region_instance_group_manager.instance_group_manager.instance_group
    balancing_mode = "UTILIZATION" # Balance by utilization
  }

  depends_on = [time_sleep.wait_for_healthcheck]
}


# ==============================================================================
# Delay: Wait for Health Check
# ------------------------------------------------------------------------------
# Purpose:
#   - Allow health check to become active before backend service is used
# ==============================================================================

resource "time_sleep" "wait_for_healthcheck" {
  depends_on      = [google_compute_health_check.http_health_check]
  create_duration = "120s"
}


# ==============================================================================
# URL Map
# ------------------------------------------------------------------------------
# Purpose:
#   - Route incoming requests to backend service
#   - Default sends all traffic to VS Code backend
# ==============================================================================

resource "google_compute_url_map" "url_map" {
  name            = "vscode-alb"
  default_service = google_compute_backend_service.backend_service.self_link
}


# ==============================================================================
# URL Map: HTTP to HTTPS Redirect
# ------------------------------------------------------------------------------
# Purpose:
#   - Bounce every cleartext request to the HTTPS endpoint
#   - Carries no backend of its own
# ==============================================================================

resource "google_compute_url_map" "redirect" {
  name = "vscode-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}


# ==============================================================================
# Target Proxies
# ------------------------------------------------------------------------------
# Purpose:
#   - Terminate TLS at the LB and forward plain HTTP to the broker in the VPC
#   - The broker itself needs no TLS configuration
# ==============================================================================

resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "vscode-https-proxy"
  url_map          = google_compute_url_map.url_map.id
  ssl_certificates = [google_compute_ssl_certificate.lb.id]
}

resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "vscode-http-proxy"
  url_map = google_compute_url_map.redirect.id
}


# ==============================================================================
# Global Forwarding Rules
# ------------------------------------------------------------------------------
# Purpose:
#   - Expose 443 for the editor and 80 purely to redirect to it
#   - Both share the one reserved static IP
# ==============================================================================

resource "google_compute_global_forwarding_rule" "https_forwarding_rule" {
  name       = "vscode-https-forwarding-rule"
  ip_address = google_compute_global_address.lb_ip.address
  target     = google_compute_target_https_proxy.https_proxy.self_link

  port_range            = "443"
  load_balancing_scheme = "EXTERNAL"
}

resource "google_compute_global_forwarding_rule" "http_forwarding_rule" {
  name       = "vscode-http-forwarding-rule"
  ip_address = google_compute_global_address.lb_ip.address
  target     = google_compute_target_http_proxy.http_proxy.self_link

  port_range            = "80"
  load_balancing_scheme = "EXTERNAL"
}