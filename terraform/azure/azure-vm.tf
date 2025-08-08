# main.tf - Terraform code to create a flawed Azure VM for code scanning demonstration.

# This provider block configures the Azure provider.
# It's a standard block and does not contain any flaws.
provider "azurerm" {
  features {}
  # NEW: We are now explicitly telling Terraform which subscription to use.
  subscription_id = var.azure_subscription_id
}

# -------------------------------------------------------------------------------------
# Intentionally Flawed Code for Demonstration Purposes
# -------------------------------------------------------------------------------------

# A new variable to track the Azure subscription ID, passed from the workflow.
variable "azure_subscription_id" {
  description = "The Azure Subscription ID for the deployment."
  type        = string
}

# A new variable to track the resource owner via GitHub username.
# This value should be passed from the GitHub Actions workflow.
variable "github_username" {
  description = "The GitHub username of the person who triggered the deployment."
  type        = string
}

# Flaw 1: Hardcoding sensitive information (admin password).
# Hardcoding secrets directly in the code is a significant security risk.
# This value should be managed securely using a tool like GitHub Secrets or Azure Key Vault.
variable "admin_password" {
  description = "The admin password for the VM. This is a flaw and should not be hardcoded."
  type        = string
  sensitive   = true
}

# Flaw 2: Overly permissive Network Security Group (NSG) rule.
# This rule allows all inbound traffic from any source to any port. 
# This is a major security flaw and exposes the VM to the public internet without restriction.
resource "azurerm_network_security_group" "flawed_nsg" {
  name                = "${var.github_username}-flawed-nsg"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.flawed_rg.name

  security_rule {
    name                       = "allow_all_inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    # CORRECTED: protocol value should be '*' instead of 'Any'
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Resource group for the VM.
resource "azurerm_resource_group" "flawed_rg" {
  name     = "${var.github_username}-flawed-rg"
  location = "eastus"
}

# Virtual network for the VM.
resource "azurerm_virtual_network" "flawed_vnet" {
  name                = "${var.github_username}-flawed-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.flawed_rg.location
  resource_group_name = azurerm_resource_group.flawed_rg.name
}

# Subnet for the VM.
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
  sku                 = "Basic"
}

# Network interface for the VM. The NSG association will be a separate resource.
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
}

# CORRECTED: New resource to associate the NSG with the NIC.
resource "azurerm_network_interface_security_group_association" "flawed_nsg_association" {
  network_interface_id      = azurerm_network_interface.flawed_nic.id
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

# -------------------------------------------------------------------------------------
# Outputs
# -------------------------------------------------------------------------------------

output "public_ip_address" {
  value = azurerm_public_ip.flawed_public_ip.ip_address
}
