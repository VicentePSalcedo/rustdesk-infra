# -----------------------------------------------------------------------------
# rustdesk-infra — Root Variables
# No defaults for account-specific values. Server Pro license is entered in the
# web console (not a file secret), so no secrets.yaml is required.
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

variable "domain_name" {
  description = "Public hostname for the web console + clients (A record -> EIP)"
  type        = string
  default     = "remote.artoriastechlab.com"
}

variable "admin_ssh_cidrs" {
  description = "Optional CIDRs allowed to SSH (e.g. tailnet). Empty = SSM-only admin."
  type        = list(string)
  default     = []
}
