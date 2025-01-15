
# Data Source to Fetch EKS Cluster Info
data "aws_eks_cluster" "eks" {
  name = var.eks_cluster_name
}