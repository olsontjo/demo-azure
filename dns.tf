provider "cloudflare" {
  email = "${var.cloudflare_email}"
  token = "${var.cloudflare_token}"
}

resource "cloudflare_record" "terraform" {
  domain  = "hashicorp.rocks"
  name    = "terraform"
  type    = "A"
  value   = "${azurerm_public_ip.demo.ip_address}"
  ttl     = "1"
  proxied = true
}

output "address" {
  value = "${cloudflare_record.terraform.hostname}"
}
