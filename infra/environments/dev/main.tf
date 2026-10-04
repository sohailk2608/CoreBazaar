terraform {
  required_version = ">= 1.10.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "network" {
  source = "../../modules/aws-network"

  name                  = "${var.environment}-corebazaar"
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  private_subnet_cidrs  = var.private_subnet_cidrs
  public_subnet_cidrs   = var.public_subnet_cidrs
  single_nat_gateway    = var.environment != "prod"

  tags = {
    Environment = var.environment
    Application = "corebazaar"
  }
}

module "kubernetes_cluster" {
  source = "../../modules/aws-eks"

  cluster_name                 = "${var.environment}-corebazaar"
  cluster_version              = var.kubernetes_version
  vpc_id                       = module.network.vpc_id
  subnet_ids                   = module.network.private_subnet_ids
  cluster_admin_cidrs          = var.cluster_admin_cidrs
  node_instance_types          = var.node_instance_types
  node_min_size                = var.node_min_size
  node_max_size                = var.node_max_size
  node_desired_size            = var.node_desired_size

  tags = {
    Environment = var.environment
    Application = "corebazaar"
  }
}
