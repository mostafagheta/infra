module "network" {
  source = "./modules/network"

  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  azs                 = var.azs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "security" {
  source = "./modules/security"

  project_name = var.project_name
  vpc_id       = module.network.vpc_id
  vpc_cidr     = module.network.vpc_cidr
  admin_cidr   = var.admin_cidr
}

module "compute" {
  source = "./modules/compute"

  project_name         = var.project_name
  public_subnet_ids    = module.network.public_subnet_ids
  private_subnet_ids   = module.network.private_subnet_ids
  master_sg_id         = module.security.master_sg_id
  worker_sg_id         = module.security.worker_sg_id
  bastion_sg_id        = module.security.bastion_sg_id
  instance_type_master = var.instance_type_master
  instance_type_worker = var.instance_type_worker
  worker_count         = var.worker_count
  key_name             = var.key_name
  master_private_ip    = var.master_private_ip
  worker_private_ips   = var.worker_private_ips
}

module "alb" {
  source = "./modules/alb"

  project_name        = var.project_name
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.public_subnet_ids
  alb_sg_id           = module.security.alb_sg_id
  worker_instance_ids = module.compute.worker_ids
  node_ports          = var.node_ports
}


