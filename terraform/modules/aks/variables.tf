variable "resource_group_name" {
  type        = string
  description = "Name of the Azure Resource Group to create"
}

variable "location" {
  type        = string
  description = "Azure region for all resources"
  default     = "australiaeast"
}

variable "cluster_name" {
  type        = string
  description = "Name of the AKS cluster"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for the AKS cluster"
  default     = "1.29"
}

variable "system_node_count" {
  type        = number
  description = "Initial number of nodes in the system node pool"
  default     = 2
}

variable "system_node_vm_size" {
  type        = string
  description = "VM SKU for the system node pool"
  default     = "Standard_D2s_v5"
}

variable "create_monitoring_node_pool" {
  type        = bool
  description = "Whether to create a dedicated node pool for monitoring workloads"
  default     = false
}

variable "monitoring_node_vm_size" {
  type        = string
  description = "VM SKU for the monitoring node pool (if created)"
  default     = "Standard_D2s_v5"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources"
  default = {
    "managed-by" = "terraform"
    "project"    = "aks-finops-toolkit"
  }
}
