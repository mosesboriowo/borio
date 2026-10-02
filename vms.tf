# -----------------------------------------------------------------------------
# Example networking so the VMs below are deployable as-is. Replace with your
# own network references in a real environment.
# -----------------------------------------------------------------------------
resource "azurerm_virtual_network" "this" {
  name                = "vnet-update-manager"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = ["10.20.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  name                 = "snet-workloads"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_network_interface" "linux" {
  name                = "nic-linux-01"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "windows" {
  name                = "nic-windows-01"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
  }
}

# -----------------------------------------------------------------------------
# Linux VM enrolled in scheduled patching.
#
# The three settings that matter for Azure Update Manager:
#   patch_mode                                     = "AutomaticByPlatform"
#   bypass_platform_safety_checks_on_user_schedule = true
#   provision_vm_agent                             = true
#
# "AutomaticByPlatform" + bypass = patch ONLY inside your maintenance window.
# Without the bypass flag, Azure may also auto-patch outside your schedule.
# -----------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "example" {
  name                = "vm-linux-01"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = "Standard_B2s"
  admin_username      = "azureuser"

  network_interface_ids = [azurerm_network_interface.linux.id]

  # Update Manager scheduled patching settings.
  patch_mode                                     = "AutomaticByPlatform"
  patch_assessment_mode                          = "AutomaticByPlatform"
  bypass_platform_safety_checks_on_user_schedule = true
  provision_vm_agent                             = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # Tags so the dynamic scope in main.tf auto-enrolls this VM.
  tags = merge(var.tags, { patch_group = "monthly" })
}

# -----------------------------------------------------------------------------
# Windows VM enrolled in scheduled patching.
# -----------------------------------------------------------------------------
resource "azurerm_windows_virtual_machine" "example" {
  name                = "vm-win-01"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = "Standard_B2s"
  admin_username      = "azureadmin"
  admin_password      = var.windows_admin_password

  network_interface_ids = [azurerm_network_interface.windows.id]

  # Update Manager scheduled patching settings.
  patch_mode                                     = "AutomaticByPlatform"
  patch_assessment_mode                          = "AutomaticByPlatform"
  bypass_platform_safety_checks_on_user_schedule = true
  provision_vm_agent                             = true
  hotpatching_enabled                            = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  tags = merge(var.tags, { patch_group = "monthly" })
}

# -----------------------------------------------------------------------------
# Explicit (static) assignment of a VM to the maintenance configuration.
#
# Use this when you want to pin specific machines to the schedule regardless of
# tags. It is complementary to the dynamic scope in main.tf; you can use either
# or both. These examples pin the two VMs above directly.
# -----------------------------------------------------------------------------
resource "azurerm_maintenance_assignment_virtual_machine" "linux" {
  location                     = azurerm_resource_group.this.location
  maintenance_configuration_id = azurerm_maintenance_configuration.patching.id
  virtual_machine_id           = azurerm_linux_virtual_machine.example.id
}

resource "azurerm_maintenance_assignment_virtual_machine" "windows" {
  location                     = azurerm_resource_group.this.location
  maintenance_configuration_id = azurerm_maintenance_configuration.patching.id
  virtual_machine_id           = azurerm_windows_virtual_machine.example.id
}
