terraform {
  backend "s3" {
    bucket = "terraform-filo-state-bucket"
    key    = "stvorlistok.best/terraform.tfstate"
    region = "eu-central-1"

    dynamodb_table = "terraform-filo-state-locks"
    encrypt        = true
  }

  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  access_key                  = var.r2_access_key
  secret_key                  = var.r2_secret_key
  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  region                      = "auto"
  endpoints {
    s3 = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
  }
}

# public access and domain connecting cannot be performed via terraform yet
resource "aws_s3_bucket" "data" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

data "cloudflare_zones" "domain" {
  filter {
    name = var.zone_name
  }
}

resource "cloudflare_page_rule" "redirect_apex_to_www" {
  zone_id  = lookup(data.cloudflare_zones.domain.zones[0], "id")
  target   = "${var.domain_name}*"
  priority = 1

  actions {
    forwarding_url {
      url         = "https://www.${var.domain_name}/$1"
      status_code = 301
    }
  }
}

# Rewrite index.html
resource "cloudflare_ruleset" "rewrite_index_html" {
  zone_id     = lookup(data.cloudflare_zones.domain.zones[0], "id")
  name        = "index.html"
  description = "Rewrite index.html"
  kind        = "zone"
  phase       = "http_request_transform"
  rules {
    action = "rewrite"
    action_parameters {
      uri {
        path {
          expression = "concat(http.request.uri.path, \"index.html\")"
        }
      }
    }
    expression = "(ends_with(http.request.uri.path, \"/\"))"
    enabled    = true
  }
}

# Allow Uptime Kuma
resource "cloudflare_filter" "uptime_kuma" {
  zone_id     = lookup(data.cloudflare_zones.domain.zones[0], "id")
  description = "Allow Uptime Kuma"
  expression  = "(http.user_agent contains \"Uptime-Kuma\")"
}
resource "cloudflare_firewall_rule" "uptime_kuma" {
  zone_id     = lookup(data.cloudflare_zones.domain.zones[0], "id")
  description = "Allow Uptime Kuma"
  filter_id   = cloudflare_filter.uptime_kuma.id
  action      = "allow"
  priority    = 1
}

# Allow only CZ/SK access
resource "cloudflare_filter" "country_block" {
  zone_id     = lookup(data.cloudflare_zones.domain.zones[0], "id")
  description = "Allow only CZ/SK access"
  expression  = "(ip.geoip.country ne \"SK\") and (ip.geoip.country ne \"CZ\")"
}
resource "cloudflare_firewall_rule" "country_block" {
  zone_id     = lookup(data.cloudflare_zones.domain.zones[0], "id")
  description = "Allow only CZ/SK access"
  filter_id   = cloudflare_filter.country_block.id
  action      = "block"
  priority    = 2
}
