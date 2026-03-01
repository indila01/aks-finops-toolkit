output "cluster_name" {
  value       = module.aks.cluster_name
  description = "Run: az aks get-credentials --resource-group <rg> --name <cluster_name>"
}

output "resource_group_name" {
  value = module.aks.resource_group_name
}

output "get_credentials_command" {
  value = "az aks get-credentials --resource-group ${module.aks.resource_group_name} --name ${module.aks.cluster_name}"
}
