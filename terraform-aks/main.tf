locals {
  # Manifiesto oficial del Ingress NGINX para nubes (instala el controller y su Service LoadBalancer)
  ingress_url = "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/cloud/deploy.yaml"

  # Carpeta de los YAML: /vagrant/kubernetes
  k8s_dir = abspath("${path.module}/../kubernetes")
}

# ---------- 1. Grupo de recursos ----------
resource "azurerm_resource_group" "rg_aks" {
  name     = var.resource_group_name
  location = var.location
}

# ---------- 2. Cluster AKS ----------
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.rg_aks.location
  resource_group_name = azurerm_resource_group.rg_aks.name
  dns_prefix          = var.cluster_name

  default_node_pool {
    name       = "nodepool1"
    node_count = var.node_count
    vm_size    = var.node_vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
  }
}

# ---------- 3. Kubeconfig para kubectl en el control-node ----------
# (se guarda en ~/.kube, fuera de la carpeta compartida, igual que la llave SSH en ~/.ssh)
resource "local_sensitive_file" "kubeconfig" {
  filename        = pathexpand("~/.kube/aks-microapp.yaml")
  content         = azurerm_kubernetes_cluster.aks.kube_config_raw
  file_permission = "0600"
}

# ---------- 4. Despliegue de la aplicación ----------
# Terraform ejecuta estos comandos de kubectl cuando el cluster ya existe:
# instala el Ingress NGINX y aplica los YAML de ../kubernetes (namespace microapp)
resource "terraform_data" "app" {
  depends_on = [local_sensitive_file.kubeconfig]

  # Se vuelve a ejecutar si se recrea el cluster o cambia algún YAML/SQL
  triggers_replace = concat(
    [azurerm_kubernetes_cluster.aks.id],
    [for f in sort(fileset(local.k8s_dir, "**")) :
      filemd5("${local.k8s_dir}/${f}")]
  )

  # Si no encuentra la carpeta, falla en el plan (antes de crear nada)
  lifecycle {
    precondition {
      condition     = fileexists("${local.k8s_dir}/kustomization.yaml")
      error_message = "No se encontro ${local.k8s_dir}/kustomization.yaml. La carpeta kubernetes debe estar al lado de terraform-aks."
    }
  }

  provisioner "local-exec" {
    working_dir = path.module
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = pathexpand("~/.kube/aks-microapp.yaml")
    }
    command = <<-EOT
      set -euo pipefail

      echo ">>> 1/5 Verificando conexion con el cluster"
      kubectl get nodes

      echo ">>> 2/5 Instalando Ingress NGINX"
      kubectl apply -f ${local.ingress_url}
      # AKS: el balanceador de Azure necesita esta ruta para saber que el controller esta vivo
      kubectl annotate svc ingress-nginx-controller -n ingress-nginx \
        service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path=/healthz --overwrite

      echo ">>> 3/5 Esperando a que el Ingress Controller este listo"
      kubectl wait -n ingress-nginx --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller --timeout=300s

      echo ">>> 4/5 Aplicando los manifiestos de la aplicacion (namespace microapp)"
      # Se reintenta: el webhook del ingress puede tardar unos segundos en quedar listo
      OK=0
      for i in 1 2 3 4 5 6; do
        if kubectl apply -k ${local.k8s_dir}; then OK=1; break; fi
        echo "Reintentando en 15s ($i/6)..."; sleep 15
      done
      if [ "$OK" != "1" ]; then echo "ERROR: no se pudieron aplicar los manifiestos"; exit 1; fi

      echo ">>> 5/5 Esperando a que los Deployments esten disponibles"
      kubectl rollout status deployment --timeout=300s -n microapp \
        consul users-db products-db orders-db users-service products-service orders-service

      echo ">>> Esperando la IP publica del Ingress"
      IP=""
      for i in $(seq 1 40); do
        IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        if [ -n "$IP" ]; then break; fi
        sleep 10
      done

      kubectl get all,ingress -n microapp
      echo "================ LISTO ================"
      echo "IP del Ingress: $IP"
      echo "curl http://$IP/api/users/"
      echo "curl http://$IP/api/products/"
      echo "curl http://$IP/api/orders/"
    EOT
  }
}
