provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "terraform" {
  name     = "Terraform"
  location = "Central US"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "myVNet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.terraform.location
  resource_group_name = azurerm_resource_group.terraform.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.terraform.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "myNSG"
  location            = azurerm_resource_group.terraform.location
  resource_group_name = azurerm_resource_group.terraform.name
}

resource "azurerm_network_security_rule" "allow_all" {
  name                        = "allow_all"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.terraform.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_public_ip" "example" {
  count               = 4
  name                = "myPublicIP-${count.index}"
  location            = azurerm_resource_group.terraform.location
  resource_group_name = azurerm_resource_group.terraform.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "my_nic" {
  count               = 4
  name                = "myNIC-${count.index}"
  location            = azurerm_resource_group.terraform.location
  resource_group_name = azurerm_resource_group.terraform.name

  ip_configuration {
    name                          = "myNICConfig-${count.index}"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.example[count.index].id
  }
}

resource "azurerm_linux_virtual_machine" "myvm" {
  count               = 4
  name                = count.index == 0 ? "Master" : "node${count.index}"
  resource_group_name = azurerm_resource_group.terraform.name
  location            = azurerm_resource_group.terraform.location
  size                = "Standard_DS2_v2"
  admin_username      = "adminuser"
  network_interface_ids = [azurerm_network_interface.my_nic[count.index].id]
  disable_password_authentication = true

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("C:/Users/ashfaq/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  # Connection block for remote-exec
  connection {
    type     = "ssh"
    user     = "adminuser"
    private_key = file("C:/Users/ashfaq/.ssh/id_rsa")
    host     = self.public_ip_address
  }

 # Provisioner to install Docker and Kubernetes
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install docker.io -y",
      
      # Kubernetes installation commands
      "sudo apt-get update && sudo apt-get install -y apt-transport-https curl",
      "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -",
      "echo 'deb https://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update",
      "sudo apt-get install -y kubeadm=1.27.2-00 kubelet=1.27.2-00 kubectl=1.27.2-00",
      "sudo apt-mark hold kubelet kubeadm kubectl"
      ]
    }
}


output "vm_private_ip_addresses" {
  value = [for nic in azurerm_network_interface.my_nic : nic.private_ip_address]
}

output "vm_public_ip_addresses" {
  value = [for ip in azurerm_public_ip.example : ip.ip_address]
}
