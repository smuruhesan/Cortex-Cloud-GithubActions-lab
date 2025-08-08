# main.tf - Terraform code to create a flawed Azure VM for code scanning demonstration.

provider "azurerm" {
  features {}
}

variable "github_username" {
  description = "The GitHub username of the person who triggered the deployment."
  type        = string
}

variable "admin_password" {
  description = "The admin password for the VM. This is a flaw and should not be hardcoded."
  type        = string
  sensitive   = true
}

# Flaw 2: Overly permissive Network Security Group (NSG) rule.
resource "azurerm_network_security_group" "flawed_nsg" {
  name                = "${var.github_username}-flawed-nsg"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.flawed_rg.name

  security_rule {
    name                       = "allow_all_inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Any"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_resource_group" "flawed_rg" {
  name     = "${var.github_username}-flawed-rg"
  location = "eastus"
}

resource "azurerm_virtual_network" "flawed_vnet" {
  name                = "${var.github_username}-flawed-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.flawed_rg.location
  resource_group_name = azurerm_resource_group.flawed_rg.name
}

resource "azurerm_subnet" "flawed_subnet" {
  name                 = "${var.github_username}-flawed-subnet"
  resource_group_name  = azurerm_resource_group.flawed_rg.name
  virtual_network_name = azurerm_virtual_network.flawed_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "flawed_public_ip" {
  name                = "${var.github_username}-flawed-public-ip"
  location            = azurerm_resource_group.flawed_rg.location
  resource_group_name = azurerm_resource_group.flawed_rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "flawed_nic" {
  name                = "${var.github_username}-flawed-nic"
  location            = azurerm_resource_group.flawed_rg.location
  resource_group_name = azurerm_resource_group.flawed_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.flawed_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.flawed_public_ip.id
  }
  
  network_security_group_id = azurerm_network_security_group.flawed_nsg.id
}

# Flaw 3: Using a known insecure or outdated VM image.
resource "azurerm_linux_virtual_machine" "flawed_vm" {
  name                = "${var.github_username}-flawed-vm"
  resource_group_name = azurerm_resource_group.flawed_rg.name
  location            = azurerm_resource_group.flawed_rg.location
  size                = "Standard_DS1_v2"
  admin_username      = "vmadmin"
  admin_password      = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.flawed_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS" # Flaw: Using an old Ubuntu 18.04 LTS image. A scanner should recommend a newer, supported version like 22.04 LTS.
    version   = "latest"
  }
}

output "public_ip_address" {
  value = azurerm_public_ip.flawed_public_ip.ip_address
}
