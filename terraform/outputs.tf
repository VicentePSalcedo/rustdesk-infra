output "relay_public_ip" {
  description = "Elastic IP of the relay — point the DNS A record here"
  value       = module.rustdesk_server.eip_public_ip
}

output "web_console_url" {
  description = "Web console (after HTTPS reverse-proxy setup; before that: http://<relay_public_ip>:21114)"
  value       = "https://${var.domain_name}"
}

output "web_console_url_bootstrap" {
  description = "Web console before HTTPS is configured"
  value       = "http://${module.rustdesk_server.eip_public_ip}:21114"
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = module.rustdesk_server.instance_id
}

output "vpc_id" {
  value = module.network.vpc_id
}
