# Tools: Supermicro Hardware Management Tool Landscape

> **X11 compatibility note:** Some older X11 systems with early BMC firmware have incomplete Redfish implementations. If Redfish calls fail or return missing endpoints on X11, fall back to ipmitool and SUM. Always update BMC firmware before extensive automation.

## Tool Selection Decision Tree

```
What is the task?
|
+-- Remote server management (BMC reachable over network)?
|   |
|   +-- Need modern RESTful API operations (BIOS config, firmware, inventory)?
|   |   --> Use curl + jq with Redfish endpoints (/redfish/v1/)
|   |
|   +-- Need basic power/sensor/SEL operations (lightweight, no HTTP)?
|   |   --> Use ipmitool -I lanplus
|   |
|   +-- Need Supermicro-specific BIOS config or firmware updates via vendor tool?
|   |   --> Use SUM (Supermicro Update Manager)
|   |
|   +-- Need Supermicro-specific IPMI extensions or Node Manager?
|   |   --> Use SMCIPMITool
|   |
|   +-- Fleet-wide automation (10+ servers)?
|       --> Use Ansible with community.general.redfish_* modules
|
+-- Local server management (running on the Supermicro host)?
|   |
|   +-- Need hardware inventory (PCI, memory, CPU, BIOS info)?
|   |   --> Use dmidecode, lshw, lspci
|   |
|   +-- Need MegaRAID RAID management (create VDs, check status, rebuild)?
|   |   --> Use storcli64
|   |
|   +-- Need BMC access from local host (no network loop)?
|       --> Use ipmitool -I open (requires /dev/ipmi0)
|
+-- Bulk firmware updates across multiple servers?
    --> Use SUM in remote batch mode or Ansible community.general.redfish_command
```

---

## ipmitool

ipmitool implements the Intelligent Platform Management Interface (IPMI 2.0) protocol. It works with any standards-compliant BMC, including Supermicro's ATEN-based BMC. Use it for lightweight, vendor-agnostic operations when you do not need Supermicro-specific features.

### Modes

| Mode | Flag | Runs On | Requires | Use When |
|---|---|---|---|---|
| **lanplus** | `-I lanplus` | Any machine | Network to BMC (UDP/623) | Remote access — encrypted IPMI v2.0 |
| **open** | `-I open` | Host OS | `/dev/ipmi0` kernel driver | Local access to the server's own BMC |
| **lan** | `-I lan` | Any machine | Network to BMC (UDP/623) | Legacy IPMI v1.5 — unencrypted, avoid |

Always use `lanplus` for remote access. Use `open` only when running on the managed server itself.

### Connection Syntax

```bash
# Remote (lanplus)
ipmitool -I lanplus -H <BMC_IP> -U <USER> -P <PASS> <command>

# Local (open)
ipmitool -I open <command>

# Environment variable pattern (recommended for scripting)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS <command>
```

### Power Control

```bash
# Check power status
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power status

# Power on
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power on

# Power off (hard — immediate, no graceful shutdown)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power off

# Graceful shutdown (sends ACPI signal to OS)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power soft

# Power cycle (off then on)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power cycle

# Hard reset (equivalent to pressing reset button)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power reset
```

### Sensor Reading

```bash
# List all sensors with current values, status, and thresholds
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sdr list

# Full sensor detail (includes thresholds and event settings)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sdr list full

# Filter by sensor type
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sdr type Temperature
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sdr type Fan
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sdr type Voltage
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sdr type "Power Supply"

# Individual sensor by name
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sensor get "CPU Temp"

# All sensor readings in compact format
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sensor list
```

### System Event Log (SEL)

```bash
# List all SEL entries (most recent last)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel list

# Show SEL summary (counts, timestamps)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel info

# Clear SEL (use with caution — deletes all events)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel clear

# Get specific entry
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel get 0x0001

# Save SEL to file before clearing
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel list > sel-backup-$(date +%Y%m%d).txt
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel clear
```

### Boot Device

```bash
# Set next boot to PXE (UEFI mode, one-time)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis bootdev pxe options=efiboot

# Set next boot to local disk (UEFI mode, one-time)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis bootdev disk options=efiboot

# Set next boot to virtual CD/DVD
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis bootdev cdrom options=efiboot

# Set next boot to BIOS setup
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis bootdev bios

# Set persistent boot device (removes options=efiboot for legacy mode, add for UEFI)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis bootdev pxe options=persistent,efiboot

# Check current boot order
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis bootparam get 5
```

### Serial Over LAN (SOL)

SOL redirects the server's serial console over the IPMI session. Use for OS console access when KVM is not available.

```bash
# Activate SOL session (interactive — press ~ + . to exit)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sol activate

# Deactivate any stuck SOL session
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sol deactivate

# Show SOL configuration
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sol info 1
```

> **SOL escape sequence:** To exit an active SOL session, press `~` then `.` (tilde-dot). This is the same escape sequence as SSH.

### BMC Management (mc)

```bash
# Show BMC information (firmware version, manufacturer, device ID)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc info

# Cold reset BMC (firmware restart, takes 30-60 seconds)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc reset cold

# Warm reset BMC (faster than cold)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc reset warm

# Show BMC GUID
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc guid

# BMC watchdog status
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc watchdog get
```

### User Management

```bash
# List all users (ID, name, enabled status)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS user list 1

# Set username for user ID 3
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS user set name 3 operator

# Set password for user ID 3
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS user set password 3 <new_password>

# Enable user ID 3
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS user enable 3

# Disable user ID 3
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS user disable 3

# Set privilege level for user ID 3 on channel 1 (4=Administrator, 3=Operator, 2=User)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS channel setaccess 1 3 privilege=4
```

### LAN / Network Configuration

```bash
# Show LAN configuration for channel 1
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan print 1

# Set static IP address
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan set 1 ipsrc static
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan set 1 ipaddr 192.168.1.50
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan set 1 netmask 255.255.255.0
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan set 1 defgw ipaddr 192.168.1.1

# Set DHCP
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan set 1 ipsrc dhcp

# Show channel info
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS channel info 1

# Show channel access (authentication types)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS channel getaccess 1
```

### Chassis Status

```bash
# Full chassis status
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis status

# Identify LED control (blink for physical location)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis identify 15    # blink for 15 seconds
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis identify 0     # stop blinking

# FRU (Field Replaceable Unit) data
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS fru print 0
```

---

## Redfish API (curl + jq)

Redfish is the preferred API for modern Supermicro management. Use it for BIOS configuration, firmware inventory, and any operation that benefits from structured JSON responses.

### Authentication Pattern

All Redfish operations require HTTPS. Use `-k` to skip certificate verification (common with self-signed certs) or set `--cacert` to provide a trusted CA.

```bash
# Basic auth (simplest, suitable for ad-hoc commands)
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Systems/1 | jq '.'

# Environment variable pattern
BMC_HOST=192.168.1.100
BMC_USER=ADMIN
BMC_PASS=mysecret
```

### System Information

```bash
# Full system resource
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Systems/1 | jq '.'

# Model, serial, manufacturer
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Systems/1 | \
  jq '{Model, SerialNumber, Manufacturer, PartNumber}'

# Power state
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Systems/1 | jq '.PowerState'

# Health status
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Systems/1 | \
  jq '.Status'

# Processor summary
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Systems/1 | \
  jq '.ProcessorSummary'

# Memory summary
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Systems/1 | \
  jq '.MemorySummary'
```

### Power Actions

```bash
# Power on
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "On"}'

# Graceful shutdown (sends ACPI signal to OS)
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "GracefulShutdown"}'

# Force power off (hard — immediate)
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "ForceOff"}'

# Force restart (hard reset)
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "ForceRestart"}'

# Graceful restart
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "GracefulRestart"}'
```

Valid `ResetType` values: `On`, `ForceOff`, `GracefulShutdown`, `GracefulRestart`, `ForceRestart`, `Nmi`, `PowerCycle`.

### BIOS Configuration

```bash
# Get current BIOS attributes
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Systems/1/Bios | \
  jq '.Attributes'

# Get current BIOS version
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Systems/1/Bios | \
  jq '.Attributes.BiosVersion // .FirmwareVersion'

# Get pending BIOS changes (staged but not yet applied)
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Systems/1/Bios/Settings | \
  jq '.Attributes'

# Stage a BIOS attribute change (takes effect on next reboot)
curl -sk -u $BMC_USER:$BMC_PASS -X PATCH \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios/Settings \
  -H 'Content-Type: application/json' \
  -d '{"Attributes": {"HyperThreading": "Enabled", "TurboMode": "Enabled"}}'

# Apply multiple BIOS settings at once
curl -sk -u $BMC_USER:$BMC_PASS -X PATCH \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios/Settings \
  -H 'Content-Type: application/json' \
  -d '{
    "Attributes": {
      "HyperThreading": "Enabled",
      "TurboMode": "Enabled",
      "VMX": "Enabled",
      "VTd": "Enabled",
      "C-States": "Disabled"
    }
  }'
```

> **BIOS change note:** Unlike Dell systems, Supermicro does not use a job queue. PATCH to `/Bios/Settings` stages the change, and it takes effect on the next server reboot. No separate job creation step is needed.

### BMC Information

```bash
# BMC firmware version and status
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Managers/1 | \
  jq '{FirmwareVersion, Status}'

# BMC network interfaces
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Managers/1/EthernetInterfaces | \
  jq '.Members[]."@odata.id"'

# Specific BMC NIC configuration
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Managers/1/EthernetInterfaces/bond0 | \
  jq '{IPv4Addresses, MACAddress, DHCPv4}'

# BMC event log
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Managers/1/LogServices/Log1/Entries | \
  jq '.Members[] | {Id, Message, Severity, Created}'
```

### Firmware Inventory and Updates

```bash
# List all firmware inventory entries
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/UpdateService/FirmwareInventory | \
  jq '.Members[]."@odata.id"'

# Get a specific firmware component's details
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/UpdateService/FirmwareInventory/<component-id> | \
  jq '{Name, Version, Status, Updateable}'

# Update firmware via SimpleUpdate (HTTP server hosting the image)
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/UpdateService/Actions/UpdateService.SimpleUpdate \
  -H 'Content-Type: application/json' \
  -d '{"ImageURI": "http://<HTTP_SERVER>/<firmware.bin>", "TransferProtocol": "HTTP"}'

# Check update service capabilities
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/UpdateService | jq '.'
```

### Thermal and Power

```bash
# Thermal sensors (all temperatures and fans)
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Chassis/1/Thermal | \
  jq '.Temperatures[] | {Name, ReadingCelsius, Status}'

# Fan speeds
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Chassis/1/Thermal | \
  jq '.Fans[] | {Name, Reading, ReadingUnits, Status}'

# Power consumption
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Chassis/1/Power | \
  jq '.PowerControl[] | {Name, PowerConsumedWatts}'

# PSU status
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Chassis/1/Power | \
  jq '.PowerSupplies[] | {Name, Status, PowerInputWatts}'
```

---

## SUM (Supermicro Update Manager)

SUM is Supermicro's proprietary CLI for BIOS and BMC management. It provides features not available through standard IPMI or Redfish, particularly BIOS configuration export/import via XML and structured firmware update workflows.

> **Download required:** SUM is not freely redistributable. Download from supermicro.com (requires account) and place in `container/` before building the Docker image. Without SUM, use Redfish for BIOS and firmware operations.

### Remote Mode Syntax

```bash
sum -i <BMC_IP> -u <BMC_USER> -p <BMC_PASS> -c <Command> [--file <file>] [options]
```

### Key Commands

```bash
# Get BIOS information (current version, available version)
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c GetBiosInfo

# Get BMC information
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c GetBmcInfo

# Export current BIOS configuration to XML
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c GetCurrentBiosCfg \
  --file /workspace/configs/bios-export-$(hostname)-$(date +%Y%m%d).xml

# Import/apply BIOS configuration from XML (takes effect on next reboot)
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c ChangeBiosCfg \
  --file /workspace/configs/bios-target.xml

# Update BIOS firmware
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c UpdateBios \
  --file /workspace/firmware/BIOS_X13.bin

# Update BMC firmware
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c UpdateBmc \
  --file /workspace/firmware/BMC_X13.bin

# Export BMC configuration
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c GetBmcCfg \
  --file /workspace/configs/bmc-export.xml

# Import BMC configuration
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c ChangeBmcCfg \
  --file /workspace/configs/bmc-target.xml
```

### SUM BIOS Config Workflow (GitOps Pattern)

```bash
# 1. Export current BIOS config from reference server
sum -i $REF_SERVER -u $BMC_USER -p $BMC_PASS -c GetCurrentBiosCfg \
  --file /workspace/configs/bios-baseline.xml

# 2. Edit the XML to set desired values, commit to git
# 3. Apply to target server
sum -i $TARGET_SERVER -u $BMC_USER -p $BMC_PASS -c ChangeBiosCfg \
  --file /workspace/configs/bios-baseline.xml

# 4. Reboot to apply
ipmitool -I lanplus -H $TARGET_SERVER -U $BMC_USER -P $BMC_PASS power cycle
```

---

## SMCIPMITool

SMCIPMITool is Supermicro's enhanced IPMI CLI with extensions beyond the standard IPMI 2.0 spec. It supports Supermicro-specific sensor groups, Node Manager power capping, and raw IPMI OEM commands.

> **Download required:** SMCIPMITool is not freely redistributable. Download from supermicro.com (requires account). Without it, use ipmitool for standard IPMI operations.

### Connection Syntax

```bash
# Remote mode
SMCIPMITool <BMC_IP> <USER> <PASS> <command>

# Environment variable pattern
SMCIPMITool $BMC_HOST $BMC_USER $BMC_PASS <command>
```

### Key Operations

```bash
# System summary
SMCIPMITool $BMC_HOST $BMC_USER $BMC_PASS summary

# Power status
SMCIPMITool $BMC_HOST $BMC_USER $BMC_PASS ipmi power status

# Power on/off
SMCIPMITool $BMC_HOST $BMC_USER $BMC_PASS ipmi power on
SMCIPMITool $BMC_HOST $BMC_USER $BMC_PASS ipmi power off

# Sensor readings
SMCIPMITool $BMC_HOST $BMC_USER $BMC_PASS sensor

# System Event Log
SMCIPMITool $BMC_HOST $BMC_USER $BMC_PASS sel list

# Node Manager — get current power reading
SMCIPMITool $BMC_HOST $BMC_USER $BMC_PASS nm power reading

# Node Manager — set power cap (watts)
SMCIPMITool $BMC_HOST $BMC_USER $BMC_PASS nm power cap set 300

# Fan mode
SMCIPMITool $BMC_HOST $BMC_USER $BMC_PASS fan mode get
SMCIPMITool $BMC_HOST $BMC_USER $BMC_PASS fan mode set <mode>

# BMC reset
SMCIPMITool $BMC_HOST $BMC_USER $BMC_PASS ipmi mc reset cold
```

---

## storcli (Broadcom MegaRAID)

storcli64 (storcli) is the command-line utility for managing Broadcom MegaRAID SAS/SATA/NVMe controllers, commonly found in Supermicro servers. It replaces the older `megacli` tool and uses the same binary architecture as Dell's perccli64.

> **Local tool:** storcli runs on the host OS and communicates with the controller via the `/dev/megaraid_sas_ioctl_node` device. It requires execution on the server running the controller, not from a remote management host.

### When to Use

- Creating, deleting, or modifying RAID virtual disks
- Checking physical disk status and SMART data
- Managing hot spares and monitoring drive rebuilds
- Flashing controller to IT (HBA) mode for software-defined storage (Ceph, ZFS)
- Checking patrol read and consistency check status

### Addressing Scheme

```
/c<controller>              -- Controller (e.g., /c0 for first controller)
/c<controller>/v<vd>        -- Virtual disk (e.g., /c0/v0)
/c<controller>/e<enc>/s<slot>  -- Physical disk (e.g., /c0/e252/s0)
/c<controller>/eall/sall    -- All physical disks on all enclosures
/c<controller>/dall         -- All disk groups
```

### Key Commands

```bash
# Show all controllers
storcli64 show

# Show controller 0 details (firmware version, cache, BBU status)
storcli64 /c0 show all

# List all virtual disks on controller 0
storcli64 /c0/vall show

# List all physical disks on controller 0
storcli64 /c0/eall/sall show

# Show physical disk details with SMART data
storcli64 /c0/eall/sall show all

# Show specific physical disk (enclosure 252, slot 0)
storcli64 /c0/e252/s0 show all

# Create RAID 1 virtual disk from two disks
storcli64 /c0 add vd r1 drives=252:0,252:1

# Create RAID 5 virtual disk from three disks
storcli64 /c0 add vd r5 drives=252:0,252:1,252:2

# Create RAID 6 virtual disk from four disks
storcli64 /c0 add vd r6 drives=252:0,252:1,252:2,252:3

# Create RAID 10 virtual disk from four disks
storcli64 /c0 add vd r10 drives=252:0,252:1,252:2,252:3

# Delete virtual disk 0 on controller 0 (DESTRUCTIVE)
storcli64 /c0/v0 del

# Set physical disk as global hot spare
storcli64 /c0/e252/s4 add hotsparedrive

# Set as dedicated hot spare for disk group 0
storcli64 /c0/e252/s4 add hotsparedrive dgs=0

# Initialize virtual disk (full — overwrites data)
storcli64 /c0/v0 start init full

# Check initialization progress
storcli64 /c0/v0 show init

# Start consistency check
storcli64 /c0/v0 start cc

# Show rebuild progress
storcli64 /c0/eall/sall show rebuild

# Show BBU (Battery Backup Unit) status
storcli64 /c0/bbu show all

# Set write policy (WB=write-back, WT=write-through)
storcli64 /c0/v0 set wrcache=WB

# Set read policy (RA=read-ahead, NORA=no read-ahead, ADRA=adaptive)
storcli64 /c0/v0 set rdcache=RA

# Show controller event log
storcli64 /c0 show events
```

### HBA / IT Mode

For software-defined storage (Ceph, ZFS, OpenZFS), RAID controllers should be in IT (initiator-target) mode, passing drives directly to the OS without any RAID abstraction. Use storcli to flash the controller to IT mode firmware.

```bash
# Check current controller mode
storcli64 /c0 show

# Flash to IT mode (requires IT mode firmware package from Broadcom)
# WARNING: This destroys all existing RAID configuration and data
# Download IT firmware from Broadcom support portal first
storcli64 /c0 download file=<it_mode_firmware.rom> noverchk
```

---

## IPMIView

IPMIView is Supermicro's Java-based GUI management application. It provides a graphical interface for BMC management, including KVM console launch, virtual media mounting, and sensor viewing.

### When to Use

- Operators who prefer a GUI over CLI
- KVM console access when HTML5 web UI is unavailable
- Virtual media mounting for OS installation
- Visual sensor/health dashboard for a single server

### When Not to Use

- Automation and scripting — use ipmitool, Redfish, or SUM instead
- Fleet management — IPMIView is designed for individual server management
- CI/CD pipelines — there is no headless/scriptable mode

> IPMIView is not included in the container toolkit. Use the BMC web UI's built-in KVM console for remote desktop access.

---

## Local Hardware Discovery Tools

These tools run on the host OS to enumerate hardware directly. They do not require BMC credentials or network access to the BMC.

### dmidecode

Reads SMBIOS/DMI data from system firmware. Provides CPU, memory, BIOS, chassis, and system information. Requires root.

```bash
# Full DMI dump
dmidecode

# System product name (motherboard model)
dmidecode -s system-product-name
# Output: SYS-620P-TRT

# System serial number
dmidecode -s system-serial-number

# Baseboard product name (the actual board part number)
dmidecode -s baseboard-product-name
# Output: X12DPT-B

# BIOS version
dmidecode -s bios-version

# BIOS release date
dmidecode -s bios-release-date

# Memory summary (all DIMM slots with size and speed)
dmidecode -t memory | grep -E "Size:|Locator:|Speed:|Manufacturer:|Part Number:"

# CPU information
dmidecode -t processor | grep -E "Version:|Core Count:|Thread Count:|Current Speed:|Max Speed:"

# Chassis type
dmidecode -t chassis | grep -E "Type:|Manufacturer:"
```

### lshw

Lists detailed hardware configuration from multiple sources (/sys, /proc, SMBIOS). Requires root for full output.

```bash
# Full hardware listing (JSON output — good for programmatic parsing)
lshw -json

# Short summary table
lshw -short

# Network devices only
lshw -class network

# Storage devices only
lshw -class storage
lshw -class disk

# Memory details
lshw -class memory

# CPU details
lshw -class processor

# All in JSON, piped to jq
lshw -json | jq '.children[] | select(.class=="network") | {product, vendor, logicalname}'
```

### lspci

Lists PCI devices from the kernel's PCI bus scan. Useful for identifying NICs, RAID controllers, GPUs, and HBAs.

```bash
# List all PCI devices (brief)
lspci

# Verbose output for all devices
lspci -v

# Show RAID/storage controllers (class 0104)
lspci -v -d ::0104

# Show Ethernet controllers (class 0200)
lspci -v -d ::0200

# Show GPU/accelerators (class 0302)
lspci -v -d ::0302

# Show kernel driver in use for each device
lspci -k

# Show kernel driver for storage controllers
lspci -k -d ::0104

# Show NVMe controllers (class 0108)
lspci -v -d ::0108

# Hierarchical topology (useful for PCIe slot mapping)
lspci -tv
```

---

## Ansible (community.general Redfish Modules)

Ansible with the `community.general` collection provides generic Redfish modules for fleet-wide automation. These modules work with any Redfish-compliant BMC, including Supermicro.

### Installation

```bash
# Install Ansible
pip install ansible

# Install community.general collection (includes Redfish modules)
ansible-galaxy collection install community.general
```

### Core Modules

| Module | Purpose |
|---|---|
| `community.general.redfish_info` | Gather system, BMC, firmware, network info via Redfish |
| `community.general.redfish_command` | Execute Redfish actions (power, boot, BMC reset) |
| `community.general.redfish_config` | Configure Redfish attributes (BIOS, BMC network, users) |

### Example Playbook: Inventory and Power Control

```yaml
---
- name: Gather Supermicro inventory
  hosts: bmc_hosts
  gather_facts: false
  vars:
    bmc_user: "{{ vault_bmc_user }}"
    bmc_password: "{{ vault_bmc_password }}"

  tasks:
    - name: Get system inventory
      community.general.redfish_info:
        baseuri: "{{ inventory_hostname }}"
        username: "{{ bmc_user }}"
        password: "{{ bmc_password }}"
        validate_certs: false
        category: Systems
        command: GetSystemInventory
      register: system_info

    - name: Print system model and serial
      ansible.builtin.debug:
        msg: "{{ system_info.redfish_facts.system.entries[0][1].Model }} / {{ system_info.redfish_facts.system.entries[0][1].SerialNumber }}"

    - name: Power on server
      community.general.redfish_command:
        baseuri: "{{ inventory_hostname }}"
        username: "{{ bmc_user }}"
        password: "{{ bmc_password }}"
        validate_certs: false
        category: Systems
        command: PowerOn
```

### Example Playbook: BIOS Configuration

```yaml
---
- name: Apply BIOS profile
  hosts: bmc_hosts
  gather_facts: false
  vars:
    bmc_user: "{{ vault_bmc_user }}"
    bmc_password: "{{ vault_bmc_password }}"

  tasks:
    - name: Set BIOS attributes (virtualization host profile)
      community.general.redfish_config:
        baseuri: "{{ inventory_hostname }}"
        username: "{{ bmc_user }}"
        password: "{{ bmc_password }}"
        validate_certs: false
        category: Systems
        command: SetBiosAttributes
        bios_attributes:
          HyperThreading: "Enabled"
          VMX: "Enabled"
          VTd: "Enabled"
          TurboMode: "Enabled"
          C-States: "Disabled"

    - name: Reboot to apply BIOS changes
      community.general.redfish_command:
        baseuri: "{{ inventory_hostname }}"
        username: "{{ bmc_user }}"
        password: "{{ bmc_password }}"
        validate_certs: false
        category: Systems
        command: GracefulRestart
```

### Inventory File Pattern

```ini
[bmc_hosts]
server01-bmc ansible_host=10.0.10.101
server02-bmc ansible_host=10.0.10.102
server03-bmc ansible_host=10.0.10.103

[bmc_hosts:vars]
ansible_connection=local
ansible_python_interpreter=/usr/bin/python3
```

---

## Container-Based Approach

Running Supermicro management tools from a container solves several practical problems:

| Problem | Container Solution |
|---|---|
| ipmitool version varies by OS package manager | Container image pins the exact version |
| SUM and SMCIPMITool require specific OS libraries | Container provides a consistent Rocky Linux environment |
| Tool installation pollutes the host system | Tools stay isolated in the container image |
| Admin team uses different host OSes (macOS, Ubuntu, Windows) | Same container image produces identical behavior everywhere |
| Reproducible automation across CI/CD pipelines | `docker build` rebuilds the exact toolkit every time |

See `architecture/README.md` for the complete container architecture, build instructions, and volume mount configuration.
