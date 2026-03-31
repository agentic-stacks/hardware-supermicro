# BIOS Configuration Management

Supermicro BIOS is managed via three paths: Redfish API (X11 with BMC firmware ≥ 1.50, all X12/X13), SUM (Supermicro Update Manager), and ipmitool for boot device overrides. Redfish is preferred for automation; SUM is preferred for full config export/import.

## View Current BIOS Settings

### All attributes via Redfish

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios | jq '.Attributes'
```

### Specific attribute via Redfish

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios | jq '.Attributes.HyperThreading'

curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios | jq '.Attributes | {HyperThreading, VMX, VTd, TurboMode}'
```

### Full BIOS config export via SUM

```bash
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c GetCurrentBiosCfg --file current-bios.xml
```

The exported XML contains every BIOS attribute with its current value, available options, and help text. This is the most complete view of BIOS state.

### Check pending (staged) BIOS settings

Changes applied via Redfish PATCH go to `/Bios/Settings` first. To see what is staged but not yet applied:

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios/Settings | jq '.Attributes'
```

## Common BIOS Settings Reference

| Category | Attribute Name | Values | Notes |
|----------|---------------|--------|-------|
| Hyper-Threading | `HyperThreading` | `Enabled`, `Disabled` | Disable for latency-sensitive NUMA workloads |
| CPU Virtualization (VT-x) | `VMX` | `Enabled`, `Disabled` | Required for hypervisors |
| VT-d (IOMMU) | `VTd` | `Enabled`, `Disabled` | Required for device passthrough |
| SR-IOV | `SR-IOV` | `Enabled`, `Disabled` | Required for NIC virtualization |
| ACS (Access Control Services) | `ACS` | `Enabled`, `Disabled` | Required for SR-IOV with IOMMU |
| Turbo Mode | `TurboMode` | `Enabled`, `Disabled` | Keep enabled for most workloads |
| C-States | `C-States` | `Enabled`, `Disabled` | Disable for latency-sensitive workloads |
| Power/Performance | `PowerPerformance` | `Performance`, `Balanced`, `PowerSaving` | Performance for servers, Balanced for mixed |
| NUMA Interleave | `NumaInterleave` | `Enabled`, `Disabled` | Disable for NUMA-aware workloads |
| Memory ECC | `MemoryECC` | `Enabled`, `Disabled` | Always keep Enabled on production servers |
| Secure Boot | `SecureBoot` | `Enabled`, `Disabled` | Required for UEFI Secure Boot chain |
| Boot Mode | `BootMode` | `UEFI`, `Legacy` | UEFI required for >2TB boot, Secure Boot |
| SR-IOV Global | `SriovGlobalEnable` | `Enabled`, `Disabled` | Global toggle for all SR-IOV capable NICs |

> **Note:** Attribute names vary between X11, X12, and X13 generations and between Supermicro board models. Always check the actual attribute names from a GET on `/redfish/v1/Systems/1/Bios` before patching.

## Change BIOS Settings via Redfish

Redfish PATCH stages changes to `/Bios/Settings`. They are applied on the next system reboot.

### Patch one or more attributes

```bash
curl -sk -u $BMC_USER:$BMC_PASS -X PATCH \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios/Settings \
  -H 'Content-Type: application/json' \
  -d '{"Attributes": {"HyperThreading": "Enabled", "VMX": "Enabled", "VTd": "Enabled"}}'
```

A `200 OK` or `204 No Content` response means the settings were staged successfully.

### Reboot to apply staged changes

```bash
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "GracefulRestart"}'
```

> **WARNING:** `GracefulRestart` sends ACPI shutdown signal to the OS before rebooting. If the OS is unresponsive, use `ForceRestart` instead, which is equivalent to a hard reset.

### Verify settings applied after reboot

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios | jq '.Attributes.HyperThreading'
```

The `/Bios` endpoint reflects the currently active (post-boot) values. `/Bios/Settings` reflects staged (pending) values.

### Check if any changes are pending

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios/Settings | jq 'if .Attributes == {} then "No pending changes" else .Attributes end'
```

## Change BIOS Settings via SUM

SUM provides a full config-as-code approach — export the entire BIOS config to XML, modify it, and import it back.

### Export current BIOS config

```bash
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c GetCurrentBiosCfg --file bios-current.xml
```

The exported XML contains `<BiosCfg>` with `<Menu>` sections for each category. Each setting is a `<Setting>` element with `name`, `order`, `selectedOption`, and `options` attributes.

### Edit the XML to change a setting

Open `bios-current.xml` and find the setting to change. For example, to enable hyper-threading:

```xml
<!-- Before -->
<Setting name="Hyper-threading [ALL]" selectedOption="Disable" type="Option">

<!-- After -->
<Setting name="Hyper-threading [ALL]" selectedOption="Enable" type="Option">
```

### Import modified config

```bash
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c ChangeBiosCfg --file bios-modified.xml
```

SUM validates the XML against the current BIOS schema before applying. If any attribute names or values are invalid, the import fails with an error message.

### Reboot to apply SUM changes

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis power cycle
```

Or gracefully via Redfish:

```bash
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "GracefulRestart"}'
```

## Apply BIOS Profile

BIOS profiles (in `profiles/`) define the recommended attribute set for a specific workload. To apply a profile:

### 1. Read the profile to understand what it sets

```bash
cat profiles/virtualization-host.yaml
```

### 2. Apply the profile attributes via Redfish PATCH

```bash
# Virtualization host (ESXi, KVM, Hyper-V)
curl -sk -u $BMC_USER:$BMC_PASS -X PATCH \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios/Settings \
  -H 'Content-Type: application/json' \
  -d '{
    "Attributes": {
      "HyperThreading": "Enabled",
      "VMX": "Enabled",
      "VTd": "Enabled",
      "SR-IOV": "Enabled",
      "ACS": "Enabled",
      "PowerPerformance": "Performance",
      "TurboMode": "Enabled",
      "C-States": "Disabled"
    }
  }'
```

```bash
# High-performance compute / bare metal
curl -sk -u $BMC_USER:$BMC_PASS -X PATCH \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios/Settings \
  -H 'Content-Type: application/json' \
  -d '{
    "Attributes": {
      "HyperThreading": "Disabled",
      "TurboMode": "Enabled",
      "C-States": "Disabled",
      "NumaInterleave": "Disabled",
      "PowerPerformance": "Performance"
    }
  }'
```

```bash
# Database server (SQL Server, Oracle, PostgreSQL)
curl -sk -u $BMC_USER:$BMC_PASS -X PATCH \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios/Settings \
  -H 'Content-Type: application/json' \
  -d '{
    "Attributes": {
      "HyperThreading": "Disabled",
      "TurboMode": "Enabled",
      "C-States": "Disabled",
      "NumaInterleave": "Disabled",
      "PowerPerformance": "Performance",
      "VMX": "Disabled"
    }
  }'
```

```bash
# Storage server (NAS, Ceph, MinIO)
curl -sk -u $BMC_USER:$BMC_PASS -X PATCH \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios/Settings \
  -H 'Content-Type: application/json' \
  -d '{
    "Attributes": {
      "HyperThreading": "Enabled",
      "TurboMode": "Enabled",
      "C-States": "Enabled",
      "PowerPerformance": "Balanced",
      "SR-IOV": "Disabled"
    }
  }'
```

### 3. Reboot to apply

```bash
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "GracefulRestart"}'
```

## Boot Order Management

### View current boot order via Redfish

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1 | jq '.Boot'
```

This shows `BootOrder`, `BootSourceOverrideTarget`, `BootSourceOverrideEnabled`, and `BootSourceOverrideMode`.

### Set persistent boot order via Redfish

```bash
curl -sk -u $BMC_USER:$BMC_PASS -X PATCH \
  https://$BMC_HOST/redfish/v1/Systems/1 \
  -H 'Content-Type: application/json' \
  -d '{
    "Boot": {
      "BootSourceOverrideEnabled": "Continuous",
      "BootSourceOverrideTarget": "Hdd"
    }
  }'
```

Valid `BootSourceOverrideTarget` values: `None`, `Pxe`, `Floppy`, `Cd`, `Usb`, `Hdd`, `BiosSetup`, `Utilities`, `Diags`, `UefiShell`, `UefiTarget`

### Set one-time boot device via ipmitool

One-time boot overrides take effect only for the next boot and then revert to the configured boot order.

```bash
# Boot to PXE (BIOS/legacy mode)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis bootdev pxe

# Boot to PXE (UEFI mode)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis bootdev pxe options=efiboot

# Boot to hard disk
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis bootdev disk

# Boot to virtual CD/DVD (for ISO installs)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis bootdev cdrom options=efiboot

# Boot to BIOS setup
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis bootdev bios
```

### Verify the boot device override is set

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis bootparam get 5
```

### Clear a pending boot override

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis bootdev none
```

## BIOS Config GitOps Workflow

Treat BIOS configuration as code — export it, version it in git, review changes in pull requests, and apply via automation.

### Step 1: Export current BIOS as baseline

```bash
# Export via Redfish (JSON — good for diffing)
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios | jq '.Attributes' > bios-baseline.json

# Export via SUM (XML — most complete, includes all options and help text)
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c GetCurrentBiosCfg --file bios-baseline.xml
```

### Step 2: Commit the baseline to git

```bash
git add bios-baseline.json bios-baseline.xml
git commit -m "chore: export BIOS baseline from $BMC_HOST"
```

### Step 3: Modify settings on the server

```bash
# Make changes via Redfish PATCH and reboot
curl -sk -u $BMC_USER:$BMC_PASS -X PATCH \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios/Settings \
  -H 'Content-Type: application/json' \
  -d '{"Attributes": {"HyperThreading": "Disabled", "C-States": "Disabled"}}'

curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "GracefulRestart"}'
```

### Step 4: Export again and diff

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios | jq '.Attributes' > bios-after.json

diff bios-baseline.json bios-after.json
```

### Step 5: Apply to other servers via Ansible

```bash
ansible-playbook playbooks/apply-bios-profile.yml \
  -i inventory/production.ini \
  -e "profile=hpc"
```

### Step 6: Commit final state

```bash
git add bios-after.json
git commit -m "feat: apply HPC BIOS profile — disable HT and C-states"
```

## Reset BIOS to Factory Defaults

> **WARNING: DESTRUCTIVE** — This resets ALL BIOS settings to factory defaults including boot order, security settings, and custom configurations. Export the current BIOS config before proceeding.

```bash
# Export current state first
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c GetCurrentBiosCfg --file bios-pre-reset.xml

# Reset to defaults via SUM
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c LoadDefaultBiosCfg

# Reboot to apply
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis power cycle
```
