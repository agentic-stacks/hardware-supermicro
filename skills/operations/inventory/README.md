# Hardware Inventory

## Remote Inventory (via Redfish)

### System Overview

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1 | jq '{Model, Manufacturer, SerialNumber, BiosVersion, PowerState, ProcessorSummary, MemorySummary}'
```

### Processors

```bash
# List all processors
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/Processors | jq '.Members[]'

# Detailed info for processor 1
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/Processors/1 | jq '{Model, TotalCores, TotalThreads, MaxSpeedMHz}'
```

### Memory

```bash
# List all DIMMs
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/Memory | jq '.Members[]'

# Detailed info for a specific DIMM
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/Memory/1 | jq '{Name, CapacityMiB, OperatingSpeedMhz, Manufacturer, PartNumber}'
```

### Storage

```bash
# List storage controllers
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/Storage | jq '.Members[]'
```

### Network Interfaces (NICs)

```bash
# List all Ethernet interfaces
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/EthernetInterfaces | jq '.Members[]'
```

### Thermal Sensors

```bash
# Temperature sensors and fan speeds
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Chassis/1/Thermal | jq '.Temperatures[] | {Name, ReadingCelsius, Status}'
```

### Power

```bash
# Power consumption
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Chassis/1/Power | jq '.PowerControl[] | {Name, PowerConsumedWatts}'
```

## Remote Inventory (via IPMI)

```bash
# Sensor Data Repository — all sensor readings
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sdr list

# FRU (Field Replaceable Unit) data — serial numbers, part numbers
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS fru list
```

## Local Inventory (Inside Privileged Container)

These commands require access to the host OS (either directly or via a privileged container with `/dev` and `/sys` mounted).

### dmidecode — SMBIOS Data

```bash
# System model
dmidecode -s system-product-name

# Serial number
dmidecode -s system-serial-number

# BIOS version
dmidecode -s bios-version

# Memory details (all populated DIMMs)
dmidecode -t memory | grep -E "Size:|Locator:|Speed:|Manufacturer:|Part Number:"

# CPU details
dmidecode -t processor | grep -E "Version:|Core Count:|Thread Count:|Current Speed:"
```

### lspci — PCI Devices

```bash
# All PCI devices
lspci

# Network adapters (class 0200)
lspci -d ::0200 -v

# RAID controllers (class 0104)
lspci -d ::0104 -v

# GPUs (class 0302)
lspci -d ::0302 -v
```

### lshw — Full Hardware Listing

```bash
# Full hardware tree in JSON format (good for parsing and archiving)
lshw -json > workspace/inventory/$(hostname)-hw.json
```

## Export Inventory for Asset Records

Script pattern to capture a full Redfish system summary:

```bash
#!/bin/bash
# Usage: ./export-inventory.sh <BMC_HOST> <BMC_USER> <BMC_PASS>
BMC_HOST=$1
BMC_USER=$2
BMC_PASS=$3
OUTPUT="workspace/inventory/${BMC_HOST}-inventory.json"

curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1 | jq '{
    Model, Manufacturer, SerialNumber, BiosVersion, PowerState,
    Processors: .ProcessorSummary,
    Memory: .MemorySummary
  }' > "$OUTPUT"

echo "Inventory exported to $OUTPUT"
```
