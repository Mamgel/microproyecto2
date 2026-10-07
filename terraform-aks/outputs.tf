output "resource_group" {
  value = azurerm_resource_group.rg_aks.name
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

# Para usar el cluster desde Cloud Shell o desde cualquier máquina con Azure CLI
output "comando_get_credentials" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.rg_aks.name} --name ${azurerm_kubernetes_cluster.aks.name}"
}
