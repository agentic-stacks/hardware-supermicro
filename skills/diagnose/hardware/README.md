# Diagnose: Hardware Failure Diagnosis

Systematic procedures for diagnosing Supermicro server hardware failures. Work through the relevant symptom section top-to-bottom. Do not skip steps.

> **X13 Platform Note:** Redfish API support is most complete on X12/X13. On X11 platforms, rely on ipmitool and the physical front panel for hardware diagnostics. Redfish Memory and Processor endpoints may return limited data on X11.

---

## Symptom: Server Won't Power On

### Decision Tree

```
Server won't power on
|
+-- Check PSU LEDs (rear of chassis)
|   +-- No LEDs on any PSU --> check power cables, PDU, circuit breaker
|   +-- Amber LED --> PSU fault detected
|   |   +-- Reseat PSU, recheck LED
|   |   +-- If still amber --> replace PSU
|   +-- Green LED --> PSU input is good, continue
|
+-- Check BMC reachability
|   +-- BMC unreachable --> go to connectivity/ troubleshooting
|   +-- BMC reachable --> try power on via IPMI
|       ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power on
|       +-- Power on succeeds --> monitor POST for errors
|       +-- Power on fails --> check SEL for errors
|           ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel list
```

### Commands

```bash
# Check chassis power status
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis status

# Check power supply sensors
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sdr type "Power Supply"

# Attempt remote power on
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power on

# Check SEL for power-related errors
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel list | grep -i "power\|psu\|voltage"

# Check power state via Redfish
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1 | jq '{PowerState, Status}'
```

If none of the above resolves it, suspect motherboard or power sequencing failure. Open a Supermicro support case.

---

## Symptom: Memory Errors

### Decision Tree

1. Check for memory-related events in the SEL
   ```bash
   ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel list | grep -i "memory\|dimm\|ecc"
   ```
   - No entries --> memory errors not yet logged, check sensors
   - Correctable ECC (CE) below 10 in 24 hours --> monitor, no immediate action
   - Correctable ECC (CE) above 100 in 24 hours --> schedule DIMM replacement
   - Uncorrectable ECC (UE) --> DIMM has failed, replace immediately

2. Check memory sensors
   ```bash
   ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sdr type "Memory"
   ```

3. Check DIMM inventory via Redfish to identify failed or missing DIMMs
   ```bash
   curl -sk -u $BMC_USER:$BMC_PASS \
     https://$BMC_HOST/redfish/v1/Systems/1/Memory | jq '.Members[]'

   # Get details on a specific DIMM (e.g., DIMM slot A1)
   curl -sk -u $BMC_USER:$BMC_PASS \
     https://$BMC_HOST/redfish/v1/Systems/1/Memory/A1 | \
     jq '{Name, Status, CapacityMiB, Manufacturer, PartNumber, SerialNumber}'
   ```

4. Identify DIMM slot location from SEL entry and cross-reference with the physical label on the chassis

5. Replace the failed DIMM following Supermicro population rules for the specific motherboard model (consult the hardware manual for your board)

**WARNING: Replacing DIMMs requires powering off the server. Schedule a maintenance window.**

---

## Symptom: CPU Thermal Throttling

### Decision Tree

1. Check current CPU and system temperatures
   ```bash
   ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sdr list | grep -i "temp\|thermal"
   ```
   - Inlet/ambient temperature above 35°C --> check datacenter cooling, check for hot aisle containment breach
   - CPU temperature above 85°C --> thermal throttling is likely active

2. Check fan status
   ```bash
   ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sdr list | grep -i fan
   ```
   - Any fan showing 0 RPM --> fan has failed, replace that fan module
   - All fans at maximum RPM but CPU still hot --> suspect airflow obstruction or thermal paste degradation

3. Check for airflow obstructions
   - Verify all blank panels are installed in empty drive bays and PCIe slots
   - Verify cable routing is not blocking airflow
   - Verify the air shroud / air baffle is properly seated over the CPUs
   - Check that the chassis cover is properly closed (open chassis raises internal temps)

4. Check power/thermal profile via Redfish
   ```bash
   curl -sk -u $BMC_USER:$BMC_PASS \
     https://$BMC_HOST/redfish/v1/Systems/1 | jq '.ProcessorSummary'
   ```

5. If temperatures remain critical with good airflow and working fans --> suspect thermal paste degradation or heatsink seating issue. Open a Supermicro support case.

---

## Symptom: Fan Failures

### Decision Tree

1. Identify the failed fan
   ```bash
   ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sdr list | grep -i fan
   ```
   Note the sensor name (e.g., "FAN1", "FANA") and its current reading.

2. Check the fan via Redfish
   ```bash
   curl -sk -u $BMC_USER:$BMC_PASS \
     https://$BMC_HOST/redfish/v1/Chassis/1/Thermal | \
     jq '.Fans[] | {Name, Status, Reading}'
   ```

3. Determine if failure is single or multiple fans
   - Single fan failure --> replace the fan module (hot-swap on most Supermicro chassis)
   - Multiple simultaneous fan failures --> suspect fan backplane or BMC fan controller issue

4. Reseat the fan module before replacing
   - After reseating, wait 30 seconds and recheck: `ipmitool ... sdr list | grep -i fan`
   - If reseated fan still shows 0 RPM --> replace the fan module

5. If replacement fan still shows failure --> check the fan connector on the system board and open a Supermicro support case

**WARNING: Operating without sufficient fan coverage will cause thermal throttling and may trigger automatic shutdown. Replace failed fans immediately.**

---

## Symptom: PSU Degradation

### Decision Tree

1. Check PSU status via IPMI
   ```bash
   ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sdr type "Power Supply"
   ```

2. Check PSU via Redfish
   ```bash
   curl -sk -u $BMC_USER:$BMC_PASS \
     https://$BMC_HOST/redfish/v1/Chassis/1/Power | \
     jq '.PowerSupplies[] | {Name, Status, PowerInputWatts, PowerOutputWatts}'
   ```

3. Check redundancy status
   ```bash
   curl -sk -u $BMC_USER:$BMC_PASS \
     https://$BMC_HOST/redfish/v1/Chassis/1/Power | \
     jq '.Redundancy[] | {Name, Mode, Status}'
   ```
   - Full redundancy --> both PSUs operational
   - Redundancy lost --> one PSU has failed, server running on single PSU

4. Check the PSU LED on the rear of the chassis
   - Green = normal
   - Amber or blinking amber = PSU fault
   - Off = no AC input or total PSU failure

5. If PSU shows degraded but LED is green --> try an AC power cycle of that PSU (disconnect/reconnect the power cable)

6. If PSU has genuinely failed
   - Confirm the server can run on the remaining PSU (check power draw vs single PSU capacity)
   - Order a replacement PSU matching the exact wattage and form factor
   - PSUs are hot-swappable on Supermicro rack-mount servers

**WARNING: If redundancy is lost, failure of the remaining PSU will cause an unplanned outage. Expedite PSU replacement.**

---

## Symptom: Chassis Intrusion Alert

### Decision Tree

1. Check SEL for chassis intrusion events
   ```bash
   ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel list | grep -i "intrusion\|chassis"
   ```

2. Verify the chassis cover is properly seated and latched

3. Clear the chassis intrusion alert after verifying the chassis is secured
   ```bash
   # Clear the SEL after confirming chassis is secure
   ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel clear
   ```

4. If the alert persists with the cover fully closed --> the intrusion switch may be misaligned or faulty. Inspect the switch mechanism on the chassis cover hinge.

---

## Symptom: PCIe Errors

### Decision Tree

1. Check SEL for PCIe-related events
   ```bash
   ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel list | grep -i "pcie\|pci\|slot"
   ```

2. Identify the affected slot from the SEL entry

3. Check PCIe slot inventory via Redfish
   ```bash
   curl -sk -u $BMC_USER:$BMC_PASS \
     https://$BMC_HOST/redfish/v1/Systems/1 | jq '.PCIeDevices'
   ```

4. Reseat the PCIe card in the affected slot
   - Power off the server: `ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power off`
   - Physically reseat the card, ensuring it is fully engaged in the slot
   - Power on and check if the error clears

5. If the error recurs after reseating:
   - Test the card in a different PCIe slot to determine if it is the card or the slot that is faulty
   - If the error follows the card --> replace the card
   - If the error follows the slot --> suspect PCIe slot damage, open a Supermicro support case

---

## System Event Log Analysis

### Pull the log

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel elist
```

### Patterns to look for

| Pattern | Indicates | Action |
|---|---|---|
| Repeated "Correctable ECC" on same DIMM | DIMM degrading | Schedule replacement |
| "Uncorrectable ECC" | DIMM failure | Replace immediately |
| "Power Supply AC Lost" | AC power interrupted | Check PDU and power cable |
| "Fan Redundancy Lost" | Fan failure | Check fans, replace failed module |
| "Thermal Threshold Exceeded" repeated | Cooling issue | Check fans, datacenter HVAC |
| "PCI System Error" | PCIe card or slot fault | Reseat card, test in different slot |
| "Machine Check Exception" | CPU or memory bus error | Check SEL context, may need board replacement |
| "Chassis Intrusion" | Cover opened or switch fault | Verify cover is seated, clear alert |

### Export the full log

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel elist > /tmp/sel_full.txt
```

---

## When to Open a Supermicro Support Case

Open a case if:
- Uncorrectable memory errors after DIMM reseat
- Multiple simultaneous component failures
- POST does not complete after reseating all components
- CPU machine check exceptions (uncorrectable)
- RAID controller not detected by OS or BMC
- Motherboard or CPU replacement is needed

### Information to gather before contacting support

```bash
# Board serial number and part number
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS fru print 0

# BMC firmware version and hardware info
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc info

# BIOS version
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios | jq '.BiosVersion'

# Full SEL export
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel elist > /tmp/sel_export.txt

# All sensor readings
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sdr dump /tmp/sdr_dump.bin
```

Supermicro support portal: https://www.supermicro.com/support/
