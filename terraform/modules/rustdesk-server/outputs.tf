output "instance_id" {
  value = aws_instance.this.id
}

output "eip_public_ip" {
  description = "Elastic IP of the relay"
  value       = aws_eip.this.public_ip
}

output "security_group_id" {
  value = aws_security_group.this.id
}
