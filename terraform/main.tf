provider "aws" {
  region = "us-east-1"
}

# Crear una nueva VPC para EKS
module "eks_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.0" # Puedes usar la última versión estable

  name = "eks-mundos-e-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Name = "eks-mundos-e-vpc"
  }
}

# Crear el clúster EKS utilizando la nueva VPC y subnets
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.0"
  cluster_name    = "eks-mundos-e"
  cluster_version = "1.27" # Cambia la versión según tus necesidades
  vpc_id          = module.eks_vpc.vpc_id
  subnet_ids      = module.eks_vpc.private_subnets

  # Usamos managed_node_groups
  eks_managed_node_groups = {
    example = {
      ami_type       = "AL2_x86_64"
      instance_types = ["m6i.large"]

      desired_capacity = 3
      max_capacity     = 5
      min_capacity     = 1
    }
  }

  enable_irsa = true

  tags = {
    Environment = "dev"
    Name        = "eks-mundos-e"
  }
}

# Regla de seguridad para permitir SSH
resource "aws_security_group_rule" "allow_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.eks.cluster_security_group_id
}

# Crear una política de IAM para acceso completo a ECR
resource "aws_iam_policy" "full_ecr_access" {
  name        = "FullECRAccessPolicy"
  description = "Policy to provide full access to ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["ecr:*"]
        Resource = "*"
      }
    ]
  })
}
