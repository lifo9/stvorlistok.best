variable "cloudflare_account_id" {
  type      = string
  sensitive = true
}

variable "r2_access_key" {
  type      = string
  sensitive = true
}

variable "r2_secret_key" {
  type      = string
  sensitive = true
}

variable "zone_name" {
  type    = string
  default = "stvorlistok.best"
}

variable "domain_name" {
  type    = string
  default = "stvorlistok.best"
}

variable "bucket_name" {
  type    = string
  default = "stvorlistok-best"
}
