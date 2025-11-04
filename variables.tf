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

# DEV ONLY
variable "subnet_public_cidr_2" {
    description = "The subnets cidr block"
    type = string
    default = "10.0.128.0/24"
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

# Image
variable "ami_id" {
    description = "Image for the instances"
    type = string
}

# Access keys
variable "access_key" {
    description = "Access key to access AWS bastion"
    type = string
}

variable "internal_key" {
    description = "Access key for bastion to other resources"
    type = string
}

# My Ip
variable "my_ip" {
    type = string
    default = "79.199.64.237/32"
}

# Subnet Regions
variable "subnet_region_a" {
    type = string
}

variable "subnet_region_b" {
    type = string
}