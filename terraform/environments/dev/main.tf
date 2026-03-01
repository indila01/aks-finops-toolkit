terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.28"
    }
  }

  # Uncomment and configure for team use (Azure Blob Storage backend)
  # backend "azurerm" {
  #   resource_group_name  = "rg-tfstate"
  #   storage_account_name = "stfinopstfstate"
  #   container_name       = "tfstate"
  #   key                  = "aks-finops-toolkit/dev/terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
}

provider "kubernetes" {
  host                   = module.aks.kube_config[0].host
  client_certificate     = base64decode(module.aks.kube_config[0].client_certificate)
  client_key             = base64decode(module.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(module.aks.kube_config[0].cluster_ca_certificate)
}

module "aks" {
  source = "../../modules/aks"

  resource_group_name         = var.resource_group_name
  cluster_name                = var.cluster_name
  location                    = var.location
  kubernetes_version          = var.kubernetes_version
  system_node_count           = var.system_node_count
  system_node_vm_size         = var.system_node_vm_size
  create_monitoring_node_pool = var.create_monitoring_node_pool
  tags                        = var.tags
}

# Monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# VPA namespace
resource "kubernetes_namespace" "vpa_system" {
  metadata {
    name = "vpa-system"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}
