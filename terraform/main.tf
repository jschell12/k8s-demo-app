provider "aws" {
  region = "us-west-1" # Replace with your desired region
}

# Variables for EKS Cluster and Node Group
variable "eks_cluster_name" {
  description = "Name of the existing EKS cluster"
  type        = string
}

variable "ami" {
  description = "AMI Id"
  type        = string
}

variable "node_group_name" {
  description = "Name of the EC2 node group"
  type        = string
  default     = "eks-ec2-node-group"
}

variable "node_instance_type" {
  description = "Instance type for the EC2 nodes"
  type        = string
  default     = "t3.medium"
}

variable "desired_capacity" {
  description = "Desired number of nodes in the group"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of nodes in the group"
  type        = number
  default     = 3
}

variable "min_size" {
  description = "Minimum number of nodes in the group"
  type        = number
  default     = 1
}

variable "subnet_ids" {
  description = "List of subnet IDs for the node group"
  type        = list(string)
}

variable "key_pair_name" {
  description = "Key pair name for SSH access"
  type        = string
  default     = null
}

# IAM Role for EC2 Instances
resource "aws_iam_role" "node_group" {
  name = "eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

# Attach Managed Policies to IAM Role
resource "aws_iam_role_policy_attachment" "node_group_policies" {
  count = length([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::895879716483:policy/AWSLoadBalancerControllerIAMPolicy"
  ])

  role = aws_iam_role.node_group.name
  policy_arn = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::895879716483:policy/AWSLoadBalancerControllerIAMPolicy"
  ][count.index]
}

data "aws_eks_cluster" "eks_cluster" {
  name = var.eks_cluster_name
}


data "aws_iam_openid_connect_provider" "oidc_provider" {
  url = data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

# IAM Role for Service Account
resource "aws_iam_role" "sa_role" {
  name = "aws-load-balancer-controller-${var.eks_cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.oidc_provider.arn
        }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${data.aws_iam_openid_connect_provider.oidc_provider.url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

# Attach the Policy to the Role
resource "aws_iam_role_policy_attachment" "policy_attachment" {
  role       = aws_iam_role.sa_role.name
  policy_arn = "arn:aws:iam::895879716483:policy/AWSLoadBalancerControllerIAMPolicy"
}

resource "aws_iam_role_policy" "eks_node_inline_policy" {
  name   = "EKSNodeInlinePolicy"
  role   = aws_iam_role.node_group.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Action: [
          "ec2:CreateTags",
          "ec2:DetachVolume",
          "ec2:AttachVolume",
          "ec2:ModifyVolume",
          "ec2:ImportVolume",
          "ec2:ModifyVolumeAttribute",
          "ec2:PauseVolumeIO",
          "ec2:DescribeReplaceRootVolumeTasks",
          "ec2:DescribeVolumesModifications",
          "ec2:DescribeVolumeAttribute",
          "ec2:CreateVolume",
          "ec2:EnableVolumeIO",
          "ec2:DeleteVolume",
          "ec2:CreateReplaceRootVolumeTask",
          "ec2:DescribeVolumeStatus",
          "ec2:DescribeVolumes"
        ],
        Resource: "*"
      }
    ]
  })
}

# EKS Managed Node Group
resource "aws_eks_node_group" "node_group" {
  cluster_name    = var.eks_cluster_name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = var.desired_capacity
    max_size     = var.max_size
    min_size     = var.min_size
  }

  tags = {
    "Name" = "eks-node-group"
  }
}
