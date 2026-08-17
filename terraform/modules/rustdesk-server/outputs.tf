output "instance_id" {
  value = aws_instance.this.id
}

output "eip_public_ip" {
  description = "Elastic IP of the relay"
  value       = aws_eip.this.public_ip
}

output "key_param_name" {
  description = "SSM Parameter Store path holding the shared key"
  value       = aws_ssm_parameter.key.name
}

output "security_group_id" {
  value = aws_security_group.this.id
}
