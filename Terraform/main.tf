
# Azure Provider source and version being used

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configures the Azure provider with default settings.

provider "azurerm" {
  features {}
}

# Create Resource Group

resource "azurerm_resource_group" "mtc-rg" {
  name     = var.resourcegroup_name
  location = "East Us"
  tags = {
    environment = "dev"
  }
}

# Create Virtual Network

resource "azurerm_virtual_network" "mtc-vn" {
  name                = "mtc-network"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "dev"
  }
}

# Create Subnet

resource "azurerm_subnet" "mtc-subnet" {
  name                 = "mtc-subnet"
  resource_group_name  = azurerm_resource_group.mtc-rg.name
  virtual_network_name = azurerm_virtual_network.mtc-vn.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create NSG

resource "azurerm_network_security_group" "mtc-sg" {
  name                = "mtc-sg"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name

  tags = {
    environment = "dev"
  }
}

# Create Network Security Rule

resource "azurerm_network_security_rule" "mtc-dev-rule" {
  name                        = "mtc-dev-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "" // use a public ip address
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.mtc-rg.name
  network_security_group_name = azurerm_network_security_group.mtc-sg.name
}

# Create Network Security Group Association

resource "azurerm_subnet_network_security_group_association" "mtc-sga" {
  subnet_id                 = azurerm_subnet.mtc-subnet.id
  network_security_group_id = azurerm_network_security_group.mtc-sg.id

}

# Create Public Ip

resource "azurerm_public_ip" "mtc-ip" {
  name                = var.public_ip_name
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

# Create Network Interface

resource "azurerm_network_interface" "mtc-nic" {
  name                = var.nic_name
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mtc-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mtc-ip.id

  }

  tags = {
    environment = "dev"
  }
}

# Create Linux Virtual Machine

resource "azurerm_linux_virtual_machine" "mtc-vm" {
  name                  = "mtc-vm"
  resource_group_name   = azurerm_resource_group.mtc-rg.name
  location              = azurerm_resource_group.mtc-rg.location
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.mtc-nic.id]

  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/mtcazurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address
      user         = "adminuser"
      identityfile = "~/.ssh/mtcazurekey"
    })

    interpreter = var.host_os == "windows" ? ["PowerShell","-Command"] : ["bash","-c"]
  }


  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  tags = {
    environment = "dev"
  }
}

data "azurerm_public_ip" "mtc-ip-data" {

  name                = azurerm_public_ip.mtc-ip.name
  resource_group_name = azurerm_resource_group.mtc-rg.name

}

output "name" {
  value = "Public IP ${azurerm_linux_virtual_machine.mtc-vm.name} : ${azurerm_linux_virtual_machine.mtc-vm.public_ip_address}"
}

# output "private_ip" {
#   value = 
# }

