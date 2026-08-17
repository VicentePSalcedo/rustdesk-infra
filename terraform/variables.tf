# -----------------------------------------------------------------------------
# rustdesk-infra — Root Variables
# No defaults for account-specific or secret values.
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming/tagging"
  type        = string
  default     = "rustdesk"
}

# --- Network ---

variable "vpc_cidr" {
  description = "CIDR block for the dedicated VPC"
  type        = string
  default     = "10.20.0.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the single public subnet"
  type        = string
}

# --- Server ---

variable "instance_type" {
  description = "EC2 instance type for the relay"
  type        = string
  default     = "t4g.micro"
}

variable "rustdesk_key" {
  description = "Shared key clients must present to register (generate: openssl rand -hex 16)"
  type        = string
  sensitive   = true
}

variable "relay_host" {
  description = "Public hostname clients use to reach the relay (A record -> EIP)"
  type        = string
  default     = ""
}

variable "admin_ssh_cidrs" {
  description = "Optional CIDRs allowed to SSH (e.g. tailnet). Empty = SSM-only admin."
  type        = list(string)
  default     = []
}
