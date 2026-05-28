terraform {
  required_version = ">= 1.3.0"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

locals {
  ops_lab = var.ops_lab_root != "" ? var.ops_lab_root : abspath("${path.module}/..")
}

resource "null_resource" "kind_cluster" {
  triggers = {
    cluster_name = var.cluster_name
    script_hash  = filesha256("${local.ops_lab}/scripts/01-kind-cluster.sh")
  }

  provisioner "local-exec" {
    command     = "${local.ops_lab}/scripts/01-kind-cluster.sh"
    working_dir = local.ops_lab
    environment = {
      CXR_KIND_CLUSTER = var.cluster_name
      PATH             = "${local.ops_lab}/bin:${env("PATH")}"
    }
  }
}

output "kube_context" {
  description = "kubectl context for the lab cluster"
  value       = "kind-${var.cluster_name}"
  depends_on  = [null_resource.kind_cluster]
}

output "next_steps" {
  value = <<-EOT
    Cluster provisioned (or already existed).
    Deploy app: ${local.ops_lab}/scripts/03-k8-up.sh
    Access: kubectl port-forward -n cxr-ui svc/cxr-ui 8081:3000
  EOT
  depends_on = [null_resource.kind_cluster]
}
