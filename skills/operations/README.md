# Supermicro Hardware Operations Skills

## Purpose

Day-two management operations for running Supermicro servers — BIOS configuration, BMC administration, RAID management, firmware updates, hardware inventory, and fleet automation via Ansible.

## Prerequisites

Set these environment variables before running any commands in sub-skills:

```bash
export BMC_HOST=192.168.1.100
export BMC_USER=ADMIN
export BMC_PASS=ADMIN
```

All `ipmitool` commands use the `lanplus` interface:

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS <command>
```

All Redfish commands use curl with `-sk` (skip TLS verification) and HTTP basic auth:

```bash
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/<path>
```

## Sub-Skills

| Sub-Skill | Path | Scope |
|-----------|------|-------|
| BIOS | [bios/](bios/) | BIOS attribute management, boot order, profiles, SUM export/import, GitOps workflow |
| BMC | [bmc/](bmc/) | BMC configuration, user/network/power/alerts management, SEL, KVM, virtual media |
| RAID | [raid/](raid/) | RAID controller management via storcli64, HBA/IT mode, Intel VROC |
| Firmware | [firmware/](firmware/) | Firmware updates for BMC, BIOS, CPLD, NICs, RAID controllers |
| Inventory | [inventory/](inventory/) | Hardware discovery, system info, component inventory, asset export |
| Ansible | [ansible/](ansible/) | Fleet automation via community.general Redfish and IPMI modules |

## Decision Tree: Which Sub-Skill to Use

```
What do you need to do?
|
+-- View or change BIOS settings (boot mode, virtualization, C-states, turbo)
|   -> bios/
|
+-- Configure BMC itself (network, users, alerts, power actions, event log)
|   -> bmc/
|
+-- Manage storage (create/delete RAID arrays, replace drives, hot spares)
|   -> raid/
|
+-- Update or rollback firmware (BMC, BIOS, CPLD, NIC, RAID controller)
|   -> firmware/
|
+-- Discover hardware, pull component inventory, get serial numbers
|   -> inventory/
|
+-- Automate changes across a fleet of servers
|   -> ansible/
```

## Common Patterns

### Always Export Before Changing

Before modifying any BIOS or BMC configuration, export the current state:

```bash
# Export current BIOS attributes via Redfish
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios | jq '.Attributes' > bios-before.json

# Export via SUM
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c GetCurrentBiosCfg --file bios-before.xml
```

This gives you a rollback baseline and a record of what changed.

### Check BMC Connectivity First

Before running any management commands, verify the BMC is reachable:

```bash
# Quick connectivity check
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc info

# Redfish connectivity check
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/ | jq '.RedfishVersion'
```

### BIOS Changes Require a Reboot

Redfish PATCH to `/Bios/Settings` stages changes — they do not take effect until the next system reboot. Always reboot to apply:

```bash
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "GracefulRestart"}'
```

### Prefer Graceful Over Forced Operations

Use graceful shutdown/restart whenever the OS is running to avoid filesystem corruption. Only use force actions when the system is unresponsive:

```bash
# Preferred: graceful
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power soft

# Last resort: hard off
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power off
```

## Initial Server Setup (ordered)

1. **BMC** — verify connectivity, configure network, set users, configure alerts
2. **Firmware** — update all firmware components to latest validated versions
3. **BIOS** — apply workload profile (virtualization, database, HPC, storage)
4. **RAID** — configure storage layout for the intended workload
5. **Inventory** — record hardware inventory and asset information

## Ongoing Maintenance

1. **Firmware** — check for and apply updates on a regular schedule
2. **Inventory** — verify hardware health, check for failed or degraded components
3. **BMC** — review System Event Log for warnings and errors
4. **Ansible** — automate fleet-wide configuration drift detection and remediation
