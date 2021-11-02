module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = local.cluster_name
  cluster_version = "1.21"
  version = "17.20.0"
  enable_irsa=true
  subnets         = module.vpc.private_subnets

  tags = {
    Environment = "development"
    GithubRepo  = "terraform-aws-eks"
    GithubOrg   = "terraform-aws-modules"
  }

  vpc_id = module.vpc.vpc_id

  node_groups_defaults = {
    ami_type  = "AL2_x86_64"
    disk_size = 50
  }

    node_groups = {
    example = {
      desired_capacity = 2
      max_capacity     = 10
      min_capacity     = 2

      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"
      k8s_labels = {
        Environment = "test"
        GithubRepo  = "terraform-aws-eks"
        GithubOrg   = "terraform-aws-modules"
      }
      additional_tags = {
        ExtraTag = "example"
      }
      update_config = {
        max_unavailable_percentage = 50 # or set `max_unavailable`
      }
    }
  }

 map_roles    = var.map_roles
 map_users    = var.map_users
 map_accounts = var.map_accounts

 write_kubeconfig   = true
 workers_additional_policies = ["arn:aws:iam::aws:policy/AWSAppMeshFullAccess","arn:aws:iam::aws:policy/AWSXrayFullAccess","arn:aws:iam::aws:policy/CloudWatchLogsFullAccess","arn:aws:iam::aws:policy/AWSCloudMapFullAccess"]

}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}
