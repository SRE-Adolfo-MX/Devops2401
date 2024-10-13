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

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

# Crear el cluster EKS utilizando la VPC y subnets predeterminadas
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  cluster_name    = "eks-mundos-e"
  vpc_id          = data.aws_vpc.default.id
  subnet_ids      = data.aws_subnet_ids.default.ids

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

# Reglas de seguridad para SSH
resource "aws_security_group_rule" "allow_ssh" {
  type            = "ingress"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  cidr_blocks     = ["0.0.0.0/0"]
  security_group_id = module.eks.worker_security_group_id
}

# Crear una política IAM para acceso completo a ECR
resource "aws_iam_policy" "full_ecr_access" {
  name        = "FullECRAccessPolicy"
  description = "Policy to provide full access to ECR"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# Adjuntar la política IAM al rol de nodos EKS
resource "aws_iam_role_policy_attachment" "eks_nodes_ecr_access" {
  role       = module.eks.worker_iam_role_name
  policy_arn = aws_iam_policy.full_ecr_access.arn
}

# Guardar la clave privada en un archivo local
resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "${path.module}/pin.pem"
  file_permission = "0600"
}
