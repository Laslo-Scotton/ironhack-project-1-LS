# REGION
variable "base_region" {
    description = "The ressources region"
    type = string
    default = "ap-northeast-2" # Seoul
}

# VPC
variable "base_cidr_block" {
    description = "This is the base VPC cidr"
    type = string
    default = "10.0.0.0/16"
}

# SUBNET
variable "subnet_public_cidr" {
    description = "The subnets cidr block"
    type = string
    default = "10.0.4.0/24"
}

variable "subnet_private_cidr" {
    description = "The subnets cidr block"
    type = string
    default = "10.0.8.0/24"
}

variable "subnet_private_db_cidr" {
    description = "The subnets cidr block"
    type = string
    default = "10.0.12.0/24"
}