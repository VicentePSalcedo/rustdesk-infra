output "relay_public_ip" {
  description = "Elastic IP of the relay — point the DNS A record here"
  value       = module.rustdesk_server.eip_public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = module.rustdesk_server.instance_id
}

output "key_param_name" {
  description = "SSM Parameter Store path holding the shared key"
  value       = module.rustdesk_server.key_param_name
}

output "vpc_id" {
  value = module.network.vpc_id
}
