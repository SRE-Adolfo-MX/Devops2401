provider "aws" {
  region = "us-east-1"
}

# Crear la clave SSH
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh_key_pair" {
  key_name   = "pin"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Referenciar la VPC y subnets predeterminadas
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  vpc_id = data.aws_vpc.default.id
}

# Crear el cluster EKS utilizando la VPC y subnets predeterminadas
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  cluster_name    = "eks-mundos-e"
  vpc_id          = data.aws_vpc.default.id
  subnet_ids      = data.aws_subnets.default.ids

  # Usamos managed_node_groups
    eks_managed_node_groups = {
    example = {
      ami_type       = "AL2_x86_64"
      instance_types = ["m6i.large"]

      desired_capacity = 3
      max_capacity     = 5
      min_capacity     = 1
      desired_size = 1
      key_name      = aws_key_pair.ssh_key_pair.key_name
    }
  }

  enable_irsa = true

  tags = {
    Environment = "dev"
    Name        = "eks-mundos-e"
  }
}





