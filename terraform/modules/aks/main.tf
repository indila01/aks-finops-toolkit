terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "system"
    node_count          = var.system_node_count
    vm_size             = var.system_node_vm_size
    os_disk_size_gb     = 80
    type               = "VirtualMachineScaleSets"
    auto_scaling_enabled = true
    min_count          = 1
    max_count           = var.system_node_count + 2

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count
    ]
  }
}

# Dedicated node pool for monitoring workloads (optional, avoids noisy-neighbour)
resource "azurerm_kubernetes_cluster_node_pool" "monitoring" {
  count                 = var.create_monitoring_node_pool ? 1 : 0
  name                  = "monitoring"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.monitoring_node_vm_size
  node_count           = 1
  auto_scaling_enabled = false
  os_disk_size_gb      = 60

  node_labels = {
    "workload-type" = "monitoring"
  }

  node_taints = [
    "workload-type=monitoring:NoSchedule"
  ]

  tags = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.cluster_name}-logs"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}
