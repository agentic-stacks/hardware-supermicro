# Diagnose: Troubleshooting Overview

Route the user's reported symptom to the correct diagnostic sub-skill. Ask clarifying questions only if the symptom category is ambiguous.

## Symptom Routing Table

| Symptom Category | Route To | Example Symptoms |
|---|---|---|
| Server won't power on, LED codes, memory errors, CPU throttling, fan failures, PSU issues | [hardware/](hardware/) | "Amber LED on front panel", "ECC errors in SEL" |
| Cannot reach BMC, web UI down, IPMI failures, NIC link down, VLAN issues | [connectivity/](connectivity/) | "Can't ping BMC", "ipmitool connection refused" |
| Drive failures, RAID degraded, foreign drives, no boot device, slow rebuild | [storage/](storage/) | "Drive showing Foreign", "VD0 is degraded" |

## Triage Decision Tree

1. Is the server physically unresponsive (no power, no LEDs, no BMC)?
   - Yes --> Go to [hardware/](hardware/) and start with "Server Won't Power On"
   - No --> continue
2. Is the server powered on but unreachable over the network?
   - Yes --> Go to [connectivity/](connectivity/) and start with "BMC Unreachable"
   - No --> continue
3. Is the server reachable but reporting storage alerts or boot failures?
   - Yes --> Go to [storage/](storage/)
   - No --> continue
4. Is the server reachable and reporting hardware alerts (memory, CPU, fan, PSU)?
   - Yes --> Go to [hardware/](hardware/) and match the specific symptom
   - No --> Gather more information: run baseline commands below to identify the fault domain

## First Steps for Any Diagnosis

Before diving into a specific sub-skill, collect baseline information:

```bash
# Get chassis status and power state
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis status

# Check recent system event log entries
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel list | tail -30

# Get all sensor readings
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sdr list

# Get system FRU data (manufacturer, part numbers, serial numbers)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS fru print
```

If the BMC is reachable via Redfish, also gather:

```bash
# System overview via Redfish
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1 | jq '{Model, SerialNumber, Status, PowerState}'

# Active faults
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/LogServices/Log1/Entries | \
  jq '.Members[] | select(.Severity == "Critical") | {Created, Message}'
```

## Escalation Criteria

Open a Supermicro support case if any of the following are true:

- Multiple component failures simultaneously (potential motherboard issue)
- Uncorrectable machine check exceptions in the SEL
- BMC is unresponsive after AC power cycle and physical reset jumper
- RAID controller is not detected by the OS or BMC
- POST does not complete after reseating all components
- Server is under warranty and a physical part replacement is required

Gather this information before contacting Supermicro support:

```bash
# System serial number and board part number
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS fru print 0

# BMC firmware version
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc info

# Full system event log
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel elist > /tmp/sel_export.txt

# BIOS version
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios | jq '.BiosVersion'
```

Supermicro support portal: https://www.supermicro.com/support/
