variable "environment" {
  description = "Environment name used for resource naming and tags."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for this environment."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC IPv4 CIDR."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones used by the VPC."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs; use one per availability zone."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs; use one per availability zone."
  type        = list(string)
}

variable "cluster_admin_cidrs" {
  description = "Trusted CIDR blocks allowed to reach the EKS public API endpoint."
  type        = list(string)
}

variable "kubernetes_version" {
  description = "Kubernetes control-plane version supported by the AWS region."
  type        = string
}

variable "node_instance_types" {
  description = "EC2 instance types for the application node group."
  type        = list(string)
  default     = ["t3.large"]
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 6
}

variable "node_desired_size" {
  type    = number
  default = 2
}
