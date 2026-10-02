# Azure Update Manager — Terraform

Terraform for [Azure Update Manager](https://learn.microsoft.com/azure/update-manager/overview)
scheduled patching: a **maintenance configuration** (the patching calendar) plus
the VM settings and assignments that put VMs on that calendar.

## Files

| File | Purpose |
|------|---------|
| `providers.tf` | Terraform + `azurerm` provider (v4.x) |
| `variables.tf` | All inputs, including the patching-window schedule |
| `main.tf` | Resource group, maintenance configuration, tag-based dynamic scope |
| `vms.tf` | Example Linux + Windows VMs with patch settings, and explicit assignments |
| `outputs.tf` | Resource group, config ID, schedule summary, enrolled VMs |
| `terraform.tfvars.example` | Copy to `terraform.tfvars` and edit |

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars (subscription_id, schedule, etc.)

export ARM_SUBSCRIPTION_ID="<your-subscription-id>"
export TF_VAR_windows_admin_password="<strong-password>"   # for the example Windows VM

terraform init
terraform plan
terraform apply
```

Authenticate first with `az login` (Azure CLI), a service principal, or managed identity.

## How the patching calendar works

The schedule lives in `azurerm_maintenance_configuration` with
`scope = "InGuestPatch"`. The `window` block defines when VMs get patched:

```hcl
window {
  start_date_time = "2026-10-15 02:00"        # first occurrence (in time_zone)
  duration        = "03:00"                    # HH:MM, between 01:30 and 03:55
  time_zone       = "UTC"                       # Windows time-zone name
  recur_every     = "1Month Second Tuesday"    # the recurrence
}
```

### `recur_every` recurrence patterns

| Value | Meaning |
|-------|---------|
| `1Day` | Every day |
| `2Day` | Every 2nd day |
| `1Week` | Weekly |
| `2Week Saturday Sunday` | Every 2nd week, Saturdays and Sundays |
| `1Month Second Tuesday` | 2nd Tuesday each month (a "Patch Tuesday" style window) |
| `1Month Last Sunday` | Last Sunday each month |
| `1Month Fourth Monday offset3` | 4th Monday + 3 days each month |
| `1Month day15` | The 15th of each month |

All driven by `var.window_recur_every` — change it in `terraform.tfvars`.

### Reboot behaviour

`reboot_setting` (in `install_patches`): `IfRequired` (default), `Never`, or `Always`.

## Putting a VM on the calendar

A VM is patched on this schedule only when **both** of these are true:

1. **The VM opts in to platform-scheduled patching.** On the VM resource:
   ```hcl
   patch_mode                                     = "AutomaticByPlatform"
   bypass_platform_safety_checks_on_user_schedule = true   # patch ONLY in your window
   provision_vm_agent                             = true
   ```
   Without `bypass_platform_safety_checks_on_user_schedule = true`, Azure may
   also auto-patch outside your window.

2. **The VM is assigned to the maintenance configuration**, by either:
   - **Dynamic scope** (`azurerm_maintenance_assignment_dynamic_scope`, in `main.tf`):
     any VM carrying the configured tags (default `patch_group = "monthly"`) is
     enrolled automatically — including VMs created later. Just tag the VM.
   - **Explicit assignment** (`azurerm_maintenance_assignment_virtual_machine`,
     in `vms.tf`): pins a specific VM regardless of tags.

### Enroll an existing VM you manage elsewhere

Tag it so the dynamic scope picks it up:

```hcl
tags = { patch_group = "monthly" }
```

and ensure its patch settings are `AutomaticByPlatform` with the bypass flag, or
add an explicit `azurerm_maintenance_assignment_virtual_machine` pointing at its
`virtual_machine_id`.

## Notes

- `*.tfvars` is git-ignored (secrets). Prefer `TF_VAR_*` env vars or Key Vault for
  passwords; the example Windows password is only to make the sample deployable.
- Arc-enabled (on-prem/other-cloud) servers use the same maintenance
  configuration via `azurerm_maintenance_assignment_dynamic_scope` with
  `resource_types = ["Microsoft.HybridCompute/machines"]`.
- Provider docs:
  [maintenance_configuration](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/maintenance_configuration),
  [maintenance_assignment_dynamic_scope](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/maintenance_assignment_dynamic_scope).
