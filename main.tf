resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# -----------------------------------------------------------------------------
# Azure Update Manager maintenance configuration (the "patching calendar").
#
# scope = "InGuestPatch" is what makes this an Update Manager schedule that
# installs OS updates inside the guest, as opposed to host/platform maintenance.
# -----------------------------------------------------------------------------
resource "azurerm_maintenance_configuration" "patching" {
  name                     = var.maintenance_config_name
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  scope                    = "InGuestPatch"
  in_guest_user_patch_mode = "User"
  tags                     = var.tags

  # The patching calendar: when and how often the window opens.
  window {
    start_date_time      = var.window_start_date_time
    expiration_date_time = var.window_expiration_date_time
    duration             = var.window_duration
    time_zone            = var.window_time_zone
    recur_every          = var.window_recur_every
  }

  install_patches {
    reboot = var.reboot_setting

    linux {
      classifications_to_include    = var.linux_classifications
      package_names_mask_to_exclude = var.linux_package_excludes
    }

    windows {
      classifications_to_include = var.windows_classifications
      kb_numbers_to_exclude      = var.windows_kb_excludes
    }
  }
}

# -----------------------------------------------------------------------------
# Dynamic scope: auto-enroll any VM in the subscription that carries the
# configured tags. New VMs with matching tags are picked up automatically, so
# you do not have to add an assignment per machine.
# -----------------------------------------------------------------------------
resource "azurerm_maintenance_assignment_dynamic_scope" "by_tag" {
  count = length(var.dynamic_scope_tags) > 0 ? 1 : 0

  name                         = "${var.maintenance_config_name}-dynamic"
  maintenance_configuration_id = azurerm_maintenance_configuration.patching.id

  filter {
    locations      = [var.location]
    resource_types = ["Microsoft.Compute/virtualMachines"]
    os_types       = ["Linux", "Windows"]
    tag_filter     = "Any"

    dynamic "tags" {
      for_each = var.dynamic_scope_tags
      content {
        tag    = tags.key
        values = tags.value
      }
    }
  }
}
