# Micro Proyecto 2 - Computación en la Nube

Despliegue automatizado de una aplicación de comercio electrónico basada en microservicios sobre Azure, con balanceo de carga HAProxy y orquestación con Kubernetes AKS.

**Universidad Autónoma de Occidente** - Facultad de Ingeniería
**Asignatura:** Computación en la Nube

## Estructura

- `Vagrantfile` y `script.sh`: control-node local en Vagrant/VirtualBox con Terraform, Ansible y Azure CLI preinstalados.
- `terraform/`: provisiona en Azure 2 VMs Ubuntu (vm-haproxy y vm-microservices) con red privada, NSG y Public IPs. Dispara Ansible al terminar.
- `ansible/`: playbook que instala Docker en vm-microservices, levanta los 11 contenedores de la aplicación e instala y configura HAProxy en vm-haproxy.
- `kubernetes/`: manifiestos YAML para el namespace microapp (Secret, Consul, 3 bases MySQL con init SQL via ConfigMap, 3 microservicios con 2 réplicas cada uno, Ingress NGINX).
- `terraform-aks/`: despliegue del cluster AKS que aplica los manifiestos de kubernetes/ automáticamente.

## Problemas resueltos

1. **Aprovisionamiento de infraestructura** (Terraform + Ansible)
2. **Balanceo de carga con HAProxy** (round robin, health checks, página de stats, tolerancia a fallos)
3. **Orquestación con Kubernetes AKS** (Deployments, Services, Ingress NGINX, escalado horizontal)
4. **Opcional:** Terraform + AKS

## Imágenes Docker

Los microservicios se construyen a partir del código fuente del Micro Proyecto 1 y se publican en Docker Hub:
- `mamgel/usuarios_servicio:1.1`
- `mamgel/productos_servicio:1.1`
- `mamgel/ordenes_servicio:1.1`
- `mamgel/frontend_servicio:1.1`

## Uso

```bash
# 1. Levantar el control-node local
vagrant up
vagrant ssh controlNode

# 2. Dentro del control-node, loguear en Azure
az login --use-device-code

# 3. Aprovisionar VMs y app (Problema 1 + 2)
cd /vagrant/terraform
terraform init
terraform apply -auto-approve

# 4. Desplegar AKS (Problema 3)
cd /vagrant/terraform-aks
terraform init
terraform apply -auto-approve

# 5. Destruir al terminar
terraform destroy -auto-approve     # desde cada carpeta
```

## Integrantes

- *Cristian Andrés Mera*
- *Miguel Ángel Mosquera*
