variable "project_name" {
  type = string
}

variable "environment" {
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

variable "admin_ssh_cidrs" {
  type    = list(string)
  default = []
}
