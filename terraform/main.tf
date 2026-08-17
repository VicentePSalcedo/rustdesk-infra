module "network" {
  source = "./modules/network"

  project_name      = var.project_name
  environment       = var.environment
  vpc_cidr          = var.vpc_cidr
  availability_zone = var.availability_zone
}

module "rustdesk_server" {
  source = "./modules/rustdesk-server"

  project_name    = var.project_name
  environment     = var.environment
  aws_region      = var.aws_region
  vpc_id          = module.network.vpc_id
  subnet_id       = module.network.subnet_id
  instance_type   = var.instance_type
  rustdesk_key    = var.rustdesk_key
  relay_host      = var.relay_host
  admin_ssh_cidrs = var.admin_ssh_cidrs
}
