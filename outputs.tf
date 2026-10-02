output "resource_group_name" {
  description = "Resource group holding the maintenance configuration and VMs."
  value       = azurerm_resource_group.this.name
}

output "maintenance_configuration_id" {
  description = "ID of the Azure Update Manager maintenance configuration."
  value       = azurerm_maintenance_configuration.patching.id
}

output "patching_schedule" {
  description = "Human-readable summary of the patching calendar."
  value = format(
    "Window opens %s (%s) for %s, recurring: %s. Reboot: %s.",
    var.window_start_date_time,
    var.window_time_zone,
    var.window_duration,
    var.window_recur_every,
    var.reboot_setting,
  )
}

output "enrolled_virtual_machines" {
  description = "VMs explicitly assigned to the maintenance configuration."
  value = [
    azurerm_linux_virtual_machine.example.name,
    azurerm_windows_virtual_machine.example.name,
  ]
}
