# ==============================================================================
# HTTP Load Balancer: Global IP, Backend Service, URL Map, Proxy, Forwarding Rule
# ------------------------------------------------------------------------------
# Purpose:
#   - Reserve static global IP for HTTP load balancer
#   - Route HTTP/80 to backend service via URL map and target proxy
#   - Distribute traffic to RStudio instance group with health checks
# ==============================================================================


# ==============================================================================
# Static Global IP Address
# ------------------------------------------------------------------------------
# Purpose:
#   - Reserve global static IP for HTTP load balancer
#   - Keep IP stable across LB updates or recreation
# ==============================================================================

resource "google_compute_global_address" "lb_ip" {
  name = "rstudio-lb-ip"
}


# ==============================================================================
# Backend Service
# ------------------------------------------------------------------------------
# Purpose:
#   - Define backend service for RStudio instance group
#   - Use health checks to gate traffic to healthy backends
# ==============================================================================

resource "google_compute_backend_service" "backend_service" {
  name          = "rstudio-backend-service"
  protocol      = "HTTP"
  port_name     = "http" # Must match named port in MIG
  health_checks = [google_compute_health_check.http_health_check.self_link]

  timeout_sec           = 10
  load_balancing_scheme = "EXTERNAL"

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
#   - Default sends all traffic to RStudio backend
# ==============================================================================

resource "google_compute_url_map" "url_map" {
  name            = "rstudio-alb"
  default_service = google_compute_backend_service.backend_service.self_link
}


# ==============================================================================
# Target HTTP Proxy
# ------------------------------------------------------------------------------
# Purpose:
#   - Terminate HTTP and forward to URL map
# ==============================================================================

resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "rstudio-http-proxy"
  url_map = google_compute_url_map.url_map.id
}


# ==============================================================================
# Global Forwarding Rule
# ------------------------------------------------------------------------------
# Purpose:
#   - Expose HTTP/80 entry point using static global IP
#   - Forward traffic to target HTTP proxy
# ==============================================================================

resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name       = "rstudio-http-forwarding-rule"
  ip_address = google_compute_global_address.lb_ip.address
  target     = google_compute_target_http_proxy.http_proxy.self_link

  port_range            = "80"       # Listen on port 80 (HTTP)
  load_balancing_scheme = "EXTERNAL" # External-facing LB
}