variable "resource_group_name" {
  description = "Grupo de recursos del cluster AKS"
  type        = string
  default     = "nube-parcial2-aks"
}

variable "location" {
  description = "Región de Azure"
  type        = string
  default     = "northcentralus"
}

variable "cluster_name" {
  description = "Nombre del cluster AKS"
  type        = string
  default     = "aks-microapp"
}

variable "node_count" {
  description = "Número de nodos del cluster"
  type        = number
  default     = 1
}

variable "node_vm_size" {
  description = "Tamaño de VM de los nodos (mínimo 2 vCPU y 4 GB de RAM)"
  type        = string
  default     = "Standard_B2as_v2"
}
