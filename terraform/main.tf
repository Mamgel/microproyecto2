resource "azurerm_resource_group" "resource_group_parcial2" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "virtual_network_parcial2" {
  name                = "vnet-parcial2"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.resource_group_parcial2.name
}

resource "azurerm_subnet" "subnet_parcial2" {
  name                 = "subnet-parcial2"
  resource_group_name  = azurerm_resource_group.resource_group_parcial2.name
  virtual_network_name = azurerm_virtual_network.virtual_network_parcial2.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Firewall: puertos abiertos desde Internet (SSH, HTTP, stats de HAProxy y microservicios)
resource "azurerm_network_security_group" "nsg_parcial2" {
  name                = "nsg-parcial2"
  location            = var.location
  resource_group_name = azurerm_resource_group.resource_group_parcial2.name

  security_rule {
    name                       = "puertos-permitidos"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "80", "8080", "3001-3013","5001","8500"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc_parcial2" {
  subnet_id                 = azurerm_subnet.subnet_parcial2.id
  network_security_group_id = azurerm_network_security_group.nsg_parcial2.id
}

# ---------- VM 1: HAProxy ----------

resource "azurerm_public_ip" "public_ip_haproxy" {
  name                = "haproxy-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.resource_group_parcial2.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic_haproxy" {
  name                = "haproxy-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.resource_group_parcial2.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_parcial2.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10"
    public_ip_address_id          = azurerm_public_ip.public_ip_haproxy.id
  }
}

resource "azurerm_linux_virtual_machine" "vm_haproxy" {
  name                  = "vm-haproxy"
  resource_group_name   = azurerm_resource_group.resource_group_parcial2.name
  location              = var.location
  size                  = "Standard_B2as_v2"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.nic_haproxy.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(pathexpand("~/.ssh/azure_key.pub"))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# ---------- VM 2: Microservicios ----------

resource "azurerm_public_ip" "public_ip_microservices" {
  name                = "microservices-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.resource_group_parcial2.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic_microservices" {
  name                = "microservices-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.resource_group_parcial2.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_parcial2.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.11"
    public_ip_address_id          = azurerm_public_ip.public_ip_microservices.id
  }
}

resource "azurerm_linux_virtual_machine" "vm_microservices" {
  name                  = "vm-microservices"
  resource_group_name   = azurerm_resource_group.resource_group_parcial2.name
  location              = var.location
  size                  = "Standard_B2as_v2"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.nic_microservices.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(pathexpand("~/.ssh/azure_key.pub"))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# ---------- Ansible ----------

# Terraform escribe el inventario con las IPs públicas que Azure asignó
resource "local_file" "inventario" {
  filename = "${path.module}/../ansible/inventory.ini"
  content  = <<-EOT
    [haproxy]
    vm-haproxy ansible_host=${azurerm_public_ip.public_ip_haproxy.ip_address}

    [microservices]
    vm-microservices ansible_host=${azurerm_public_ip.public_ip_microservices.ip_address}

    [all:vars]
    ansible_user=azureuser
    ansible_ssh_private_key_file=~/.ssh/azure_key
    ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
  EOT
}

# Al crear las VMs, Terraform ejecuta Ansible automáticamente
resource "terraform_data" "ansible" {
  depends_on = [
    azurerm_linux_virtual_machine.vm_haproxy,
    azurerm_linux_virtual_machine.vm_microservices,
    local_file.inventario,
  ]

  # Se vuelve a ejecutar si cambian las VMs, el playbook o el compose
    triggers_replace = concat(
    [
      azurerm_linux_virtual_machine.vm_haproxy.id,
      azurerm_linux_virtual_machine.vm_microservices.id,
      filemd5("${path.module}/../ansible/playbook.yml"),
    ],
    [for f in sort(fileset("${path.module}/../ansible/files", "**")) :
      filemd5("${path.module}/../ansible/files/${f}")]
  )

  provisioner "local-exec" {
    working_dir = "${path.module}/../ansible"
    command     = "ansible-playbook -i inventory.ini playbook.yml"
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
      ANSIBLE_FORCE_COLOR       = "1"
    }
  }
}
