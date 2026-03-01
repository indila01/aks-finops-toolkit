variable "resource_group_name" {
  type        = string
  description = "Name of the Azure Resource Group to create"
  default     = "rg-finops-dev"
}

variable "cluster_name" {
  type        = string
  description = "Name of the AKS cluster"
  default     = "aks-finops-dev"
}

variable "location" {
  type        = string
  description = "Azure region (e.g. australiaeast, eastus, westeurope)"
  default     = "australiaeast"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for the AKS cluster. Use: az aks get-versions --location <region> -o table"
  default     = "1.29"
}

variable "system_node_count" {
  type        = number
  description = "Initial node count for the system node pool. Min 2 recommended for HA."
  default     = 2
}

variable "system_node_vm_size" {
  type        = string
  description = "VM SKU for the system node pool. Standard_D2s_v5 = 2 vCPU, 8Gi RAM."
  default     = "Standard_D2s_v5"
}

variable "create_monitoring_node_pool" {
  type        = bool
  description = "Whether to create a dedicated node pool for monitoring workloads (tainted for monitoring only)."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources"
  default = {
    "environment" = "dev"
    "managed-by"  = "terraform"
    "project"     = "aks-finops-toolkit"
  }
}
