# outputs.tf — lo que Terraform muestra al final del apply
output "ip_publica_haproxy" {
  value = azurerm_public_ip.public_ip_haproxy.ip_address
}

output "ip_publica_microservices" {
  value = azurerm_public_ip.public_ip_microservices.ip_address
}

output "ssh_haproxy" {
  value = "ssh -i ~/.ssh/azure_key azureuser@${azurerm_public_ip.public_ip_haproxy.ip_address}"
}

output "ssh_microservices" {
  value = "ssh -i ~/.ssh/azure_key azureuser@${azurerm_public_ip.public_ip_microservices.ip_address}"
}

output "frontend_url" {
  value = "http://${azurerm_public_ip.public_ip_microservices.ip_address}:5001"
}
