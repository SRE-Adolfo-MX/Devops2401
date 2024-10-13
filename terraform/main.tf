provider "aws" {
  region = "us-east-1"
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh_key_pair" {
  key_name   = "pin"  
  public_key = tls_private_key.ssh_key.public_key_openssh
}

module "eks_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.11.0"

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


module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "19.15.0"
  cluster_name    = "eks-mundos-e"
  cluster_version = "1.27"
  subnets         = module.eks_vpc.private_subnets
  vpc_id          = module.eks_vpc.vpc_id

  node_groups = {
    eks_nodes = {
      desired_capacity = 3
      max_capacity     = 5
      min_capacity     = 1

      instance_type = "t3.small"
      key_name      = aws_key_pair.ssh_key_pair.key_name 
    }
  }

  manage_aws_auth = true


  enable_irsa = true

  tags = {
    Environment = "dev"
    Name        = "eks-mundos-e"
  }
}


resource "aws_security_group_rule" "allow_ssh" {
  type            = "ingress"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  cidr_blocks     = ["0.0.0.0/0"] 
  security_group_id = module.eks.worker_security_group_id
}


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

resource "aws_iam_role_policy_attachment" "eks_nodes_ecr_access" {
  role       = module.eks.worker_iam_role_name
  policy_arn = aws_iam_policy.full_ecr_access.arn
}


resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "${path.module}/pin.pem"

  
  file_permission = "0600"
}
