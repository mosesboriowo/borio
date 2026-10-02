variable "subscription_id" {
  description = "Azure subscription ID to deploy into."
  type        = string
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group that holds the maintenance configuration and VMs."
  type        = string
  default     = "rg-update-manager"
}

variable "windows_admin_password" {
  description = "Admin password for the example Windows VM. Prefer a Key Vault reference or TF_VAR env var over a committed value."
  type        = string
  sensitive   = true
  default     = null
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    environment = "prod"
    managed_by  = "terraform"
    purpose     = "azure-update-manager"
  }
}

# -----------------------------------------------------------------------------
# Patching calendar / maintenance window
# -----------------------------------------------------------------------------

variable "maintenance_config_name" {
  description = "Name of the Azure Update Manager maintenance configuration."
  type        = string
  default     = "mc-monthly-patching"
}

variable "window_start_date_time" {
  description = <<-EOT
    First occurrence of the patching window, in "YYYY-MM-DD HH:MM" 24-hour form.
    This is interpreted in the time zone set by window_time_zone.
  EOT
  type        = string
  default     = "2026-10-15 02:00"
}

variable "window_expiration_date_time" {
  description = "Optional date/time the schedule stops recurring (null = never expires)."
  type        = string
  default     = null
}

variable "window_duration" {
  description = "How long the patching window stays open, as HH:MM (min 01:30, max 03:55)."
  type        = string
  default     = "03:00"
}

variable "window_time_zone" {
  description = "Windows time-zone name for the schedule, e.g. 'UTC', 'Pacific Standard Time', 'GMT Standard Time'."
  type        = string
  default     = "UTC"
}

variable "window_recur_every" {
  description = <<-EOT
    Recurrence of the patching window. Examples:
      "1Day"                         -> every day
      "1Week"                        -> weekly
      "2Week Saturday Sunday"        -> every 2nd week, Sat & Sun
      "1Month Second Tuesday"        -> 2nd Tuesday of each month (classic "Patch Tuesday+")
      "1Month Last Sunday"           -> last Sunday of each month
      "1Month Fourth Monday offset3" -> 4th Monday + 3 days each month
  EOT
  type        = string
  default     = "1Month Second Tuesday"
}

variable "reboot_setting" {
  description = "Reboot behaviour during patching: 'IfRequired', 'Never', or 'Always'."
  type        = string
  default     = "IfRequired"

  validation {
    condition     = contains(["IfRequired", "Never", "Always"], var.reboot_setting)
    error_message = "reboot_setting must be one of IfRequired, Never, or Always."
  }
}

# -----------------------------------------------------------------------------
# Patch classifications
# -----------------------------------------------------------------------------

variable "linux_classifications" {
  description = "Linux package classifications to install during the window."
  type        = list(string)
  default     = ["Critical", "Security"]
}

variable "windows_classifications" {
  description = "Windows update classifications to install during the window."
  type        = list(string)
  default     = ["Critical", "Security", "UpdateRollup", "Updates"]
}

variable "linux_package_excludes" {
  description = "Linux package names/patterns to exclude from patching."
  type        = list(string)
  default     = []
}

variable "windows_kb_excludes" {
  description = "Windows KB numbers to exclude (e.g. ['KB5000001'])."
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Dynamic scope targeting (tag-based)
# -----------------------------------------------------------------------------

variable "dynamic_scope_tags" {
  description = <<-EOT
    Tags a VM must carry to be auto-enrolled into this maintenance configuration
    via a dynamic scope. Leave empty to rely only on the explicit assignments.
  EOT
  type        = map(list(string))
  default = {
    patch_group = ["monthly"]
  }
}
