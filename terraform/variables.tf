variable "cluster_name" {
  description = "kind cluster name (must match CXR_KIND_CLUSTER)"
  type        = string
  default     = "cxr-lab"
}

variable "ops_lab_root" {
  description = "Absolute path to cxr-ops-lab (auto-detected if empty)"
  type        = string
  default     = ""
}
