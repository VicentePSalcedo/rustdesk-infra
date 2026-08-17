variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t4g.micro"
}

variable "rustdesk_key" {
  type      = string
  sensitive = true
}

variable "relay_host" {
  type    = string
  default = ""
}

variable "admin_ssh_cidrs" {
  type    = list(string)
  default = []
}
