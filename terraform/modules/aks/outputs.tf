output "cluster_name" {
  value       = azurerm_kubernetes_cluster.this.name
  description = "AKS cluster name"
}

output "resource_group_name" {
  value       = azurerm_resource_group.this.name
  description = "Resource group containing the cluster"
}

output "kube_config" {
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
  description = "Raw kubeconfig for the cluster"
}

output "cluster_id" {
  value       = azurerm_kubernetes_cluster.this.id
  description = "AKS cluster resource ID"
}

output "kubelet_identity_object_id" {
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  description = "Object ID of the kubelet managed identity (for RBAC assignments)"
}
