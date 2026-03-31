# Concepts: Supermicro Server Architecture

## Supermicro Server Platforms

Supermicro designates motherboard generations using an "X" prefix followed by a number. Each generation corresponds to a specific Intel Xeon processor family and a BMC firmware generation. The platform designation refers to the motherboard chipset, not just the chassis.

| Platform | Processor Families | BMC Firmware | Example Models | Release Timeframe |
|---|---|---|---|---|
| X11 | Xeon Scalable Gen 1/2 (Skylake/Cascade Lake) | BMC 1.x–3.x | SYS-6029P-TR, SYS-1029P-WTR, SYS-2049U-TR4 | 2017–2019 |
| X12 | Xeon Scalable Gen 3 (Ice Lake) | BMC 1.x–2.x | SYS-620P-TRT, SYS-120P-WTR, SYS-220P-C9RT | 2021–2022 |
| X13 | Xeon Scalable Gen 4/5 (Sapphire Rapids/Emerald Rapids) | BMC 1.x+ | SYS-621P-TR, SYS-121P-TN10R, SYS-221P-C9R | 2023–present |

### Naming Convention

Supermicro model names are less rigidly systematic than Dell's, but follow a general pattern. Take `SYS-6029P-TR` as an example:

```
SYS  - 60  - 29  -  P  -  TR
 |     |      |     |     |
 |     |      |     |     +-- Features: T=10GbE NIC, R=redundant PSU
 |     |      |     +-------- Product line: P=performance/professional
 |     |      +-------------- Generation indicator: 29=X11 era (Skylake/Cascade Lake)
 |     +--------------------- Form factor / socket: 60=2U 2-socket, 10=1U 1-socket, 20=2U 1-socket
 +--------------------------- System prefix (SYS = complete system, SSG = storage, SBA = blade)
```

Common form factor prefixes:

| Prefix | Meaning |
|---|---|
| `10` | 1U single-socket |
| `11` | 1U single-socket (alternate) |
| `12` | 1U/2U single-socket (newer) |
| `20` | 2U single-socket |
| `22` | 2U single-socket (newer) |
| `60` | 2U dual-socket |
| `62` | 2U dual-socket (newer) |
| `74` / `74` | 4U multi-node or large-form |

Feature suffix examples:

| Suffix | Meaning |
|---|---|
| `T` | 10GbE Base-T NIC onboard |
| `R` | Redundant power supplies |
| `N` | NVMe support |
| `F` | FatTwin / multi-node |
| `WTR` | W=wide, T=10GbE, R=redundant PSU |
| `TRT` | T=10GbE, R=redundant PSU, T=tower or twin |

> **Note:** Supermicro naming is less systematic than Dell's. The same suffix can mean different things across product families. Always check the product page or datasheet for the specific model.

### Identifying the Platform from a Running System

```bash
# Via dmidecode (local, requires root)
dmidecode -s baseboard-product-name
# Output example: X12DPT-B

# Via Redfish
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Systems/1 | jq '.Model'

# Via ipmitool
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS fru print 0
# Look for "Product Name" line
```

---

## BMC (Baseboard Management Controller)

Supermicro uses an ATEN-based BMC (the ATEN PILOT chipset) as its embedded management controller. Like all BMCs, it operates independently of the host OS — the server does not need to be powered on for the BMC to function as long as standby power is present.

> **Comparison for Dell operators:** Supermicro's BMC is functionally equivalent to Dell's iDRAC, but with fewer proprietary abstractions. Operations that Dell encapsulates in racadm or Server Configuration Profiles are done directly via IPMI commands or Redfish API calls on Supermicro. There is no racadm equivalent — the primary vendor-specific tools are SUM and SMCIPMITool.

### Access Methods

| Method | Protocol | Port | Use When |
|---|---|---|---|
| Web UI | HTTPS | 443 | Initial setup, visual inspection, KVM console launch |
| Redfish API | HTTPS (REST) | 443 | Automation, config management, firmware updates |
| IPMI | UDP | 623 | Power control, sensor reading, SEL access, SOL |
| SSH | TCP | 22 | Some BMC versions support SSH shell access |
| KVM Console | HTTPS (HTML5/Java) | 443 | Remote keyboard/video/mouse access |

### Core Capabilities

| Capability | Description |
|---|---|
| **Remote Power Control** | Power on, power off, graceful shutdown, reset, power cycle |
| **KVM Console** | HTML5 or Java-based virtual console (keyboard/video/mouse) over HTTPS |
| **Virtual Media** | Mount ISO images or USB disk images remotely |
| **Hardware Monitoring** | Temperatures, fan speeds, voltages, power consumption, intrusion detection |
| **Firmware Management** | Update BMC, BIOS, CPLD, and other components via web UI, SUM, or Redfish |
| **IPMI 2.0** | Full IPMI 2.0 support — power, sensors, SEL, SOL, user management |
| **Redfish API** | DMTF Redfish standard plus Supermicro OEM extensions |
| **Alerting** | SNMP traps, email alerts, syslog forwarding, Redfish event subscriptions |
| **Node Manager** | Intel Node Manager for power capping and thermal management (supported via IPMI) |

### BMC Web UI

Access the BMC web interface by navigating to `https://<BMC_IP>` in a browser. Default credentials (factory reset):

- Username: `ADMIN`
- Password: `ADMIN`

> **Security note:** Always change the default password immediately. Factory default `ADMIN`/`ADMIN` is a well-known vulnerability.

Key web UI sections:

| Section | Purpose |
|---|---|
| Dashboard | System health overview, power state, recent events |
| System | Hardware inventory — CPU, memory, storage, NICs |
| IPMI | IPMI settings, user management, network configuration |
| Remote Control | Launch KVM console, virtual media mount |
| Maintenance | Firmware update, BIOS config export/import, factory reset |
| Configuration | BMC network, time, alert settings |

---

## BMC vs iDRAC: Comparison for Dell Operators

Operators familiar with Dell's iDRAC will find Supermicro's BMC conceptually similar but with a different toolchain.

| Aspect | Supermicro BMC | Dell iDRAC |
|---|---|---|
| **Standard Protocol** | IPMI 2.0 + Redfish | IPMI 2.0 + Redfish + racadm + WS-Man |
| **Vendor CLI** | SMCIPMITool, SUM | racadm |
| **Config Management** | Redfish PATCH + SUM XML | Server Configuration Profile (SCP) |
| **Firmware Update** | SUM, Redfish SimpleUpdate | racadm DUP, Redfish SimpleUpdate, DSU |
| **RAID CLI** | storcli (Broadcom MegaRAID) | perccli64 (Broadcom PERC), mvcli (Marvell BOSS) |
| **Fleet Automation** | Ansible community.general Redfish modules, SUM batch | Ansible dellemc.openmanage collection |
| **Licensing** | No tiered license required | iDRAC Basic/Express/Enterprise/Datacenter tiers |
| **Virtual Console** | Available by default (HTML5/Java) | Requires Enterprise license or higher |
| **Virtual Media** | Available by default | Requires Enterprise license or higher |
| **Job Queue** | No persistent job queue | Lifecycle Controller job queue |
| **BIOS Apply** | Immediate on reboot (no job required) | Staged to job queue, requires explicit reboot job |

Key takeaway: Supermicro BMC is closer to the raw IPMI/Redfish standard. Dell iDRAC adds proprietary abstractions (job queue, SCP, racadm groups) on top. Supermicro requires fewer proprietary tools but also provides fewer guardrails.

---

## Redfish API on Supermicro

Redfish is a DMTF industry-standard RESTful API for server management. Supermicro implements the standard Redfish specification plus Supermicro OEM extensions under `/redfish/v1/Oem/Supermicro/`.

### Base Endpoints

| Endpoint | Purpose |
|---|---|
| `/redfish/v1/` | Service root — API version, links to top-level resources |
| `/redfish/v1/Systems/1` | System overview: model, serial, power state, health, BIOS version |
| `/redfish/v1/Systems/1/Bios` | Current BIOS attribute values |
| `/redfish/v1/Systems/1/Bios/Settings` | Pending BIOS changes (PATCH here to stage BIOS changes) |
| `/redfish/v1/Chassis/1` | Physical chassis: thermal sensors, power, fans |
| `/redfish/v1/Managers/1` | BMC manager: firmware version, network config, logs |
| `/redfish/v1/Managers/1/EthernetInterfaces` | BMC network interface configuration |
| `/redfish/v1/UpdateService` | Firmware update operations |
| `/redfish/v1/UpdateService/FirmwareInventory` | Installed firmware versions for all components |
| `/redfish/v1/AccountService` | BMC user account management |
| `/redfish/v1/EventService` | Event subscriptions (SNMP, syslog, Redfish events) |
| `/redfish/v1/SessionService/Sessions` | Session-based authentication |

### Supermicro OEM Extensions

| Endpoint | Purpose |
|---|---|
| `/redfish/v1/Oem/Supermicro/` | Supermicro-specific root OEM resource |
| `/redfish/v1/Systems/1/Oem/Supermicro/` | System-level OEM data (Node Manager, etc.) |
| `/redfish/v1/Managers/1/Oem/Supermicro/` | BMC OEM management operations |

### Authentication

Redfish on Supermicro BMC uses HTTP Basic Authentication over HTTPS. All requests must use HTTPS (port 443). The default self-signed certificate will trigger TLS warnings — use `-k` in curl for automation, or install a trusted certificate on the BMC.

```bash
# Basic auth example
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Systems/1 | jq '.'
```

### Session-Based Authentication

For multiple requests in a script, create a session once to avoid re-authenticating on every call:

```bash
# Create session and capture the token
TOKEN=$(curl -sk -X POST https://$BMC_HOST/redfish/v1/SessionService/Sessions \
  -H 'Content-Type: application/json' \
  -d "{\"UserName\": \"$BMC_USER\", \"Password\": \"$BMC_PASS\"}" \
  -D - 2>/dev/null | grep -i X-Auth-Token | awk '{print $2}' | tr -d '\r')

# Use session token for subsequent requests
curl -sk -H "X-Auth-Token: $TOKEN" https://$BMC_HOST/redfish/v1/Systems/1 | jq '.PowerState'

# Delete session when done
SESSION_URL=$(curl -sk -X POST https://$BMC_HOST/redfish/v1/SessionService/Sessions \
  -H 'Content-Type: application/json' \
  -d "{\"UserName\": \"$BMC_USER\", \"Password\": \"$BMC_PASS\"}" | jq -r '."@odata.id"')
curl -sk -H "X-Auth-Token: $TOKEN" -X DELETE https://$BMC_HOST$SESSION_URL
```

### Common Redfish Operations

```bash
# Get system power state
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Systems/1 | jq '.PowerState'

# Get model and serial number
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Systems/1 | jq '{Model, SerialNumber, Manufacturer}'

# Get BMC firmware version
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Managers/1 | jq '.FirmwareVersion'

# Power on the server
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "On"}'

# Graceful shutdown
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "GracefulShutdown"}'

# Force restart
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "ForceRestart"}'

# Get current BIOS attributes
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Systems/1/Bios | jq '.Attributes'

# Get firmware inventory
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/UpdateService/FirmwareInventory | jq '.Members[]."@odata.id"'
```

---

## Out-of-Band vs In-Band Management

| Property | Out-of-Band (OOB) | In-Band |
|---|---|---|
| **Network Path** | Dedicated BMC NIC or shared LOM | Host OS network interface |
| **Requires Host OS** | No | Yes |
| **Tools** | ipmitool (remote), Redfish API, SUM (remote), web UI | ipmitool (local), dmidecode, lshw, lspci, storcli |
| **Power State** | Works when server is off (standby power) | Requires server powered on with OS running |
| **Use When** | Server is unresponsive, OS not installed, remote BIOS changes, firmware updates | Collecting local inventory, running diagnostics with OS context, RAID management via storcli |

Decision rule: **Prefer out-of-band management for all remote operations.** Use in-band only when the task specifically requires host OS context (e.g., mapping PCI devices to OS network interface names, running storcli for RAID controller access, or reading SMBIOS via dmidecode).

---

## BIOS vs UEFI on Supermicro Systems

All Supermicro X11/X12/X13 servers ship with UEFI firmware. References to "BIOS" in Supermicro documentation and tools typically mean the system setup configuration (accessed via Redfish `/Systems/1/Bios` or the SUM tool), not legacy BIOS mode.

| Setting | Meaning |
|---|---|
| UEFI boot mode | Default and recommended for all X11/X12/X13 |
| Legacy (BIOS) boot mode | Deprecated; avoid for new deployments; some older X11 might use it |
| CSM (Compatibility Support Module) | Required to boot legacy OSes; disable for pure UEFI environments |

```bash
# Check current boot mode via Redfish
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Systems/1/Bios | \
  jq '.Attributes | {BootMode, CSM}'

# Check boot mode via ipmitool chassis status
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis status

# Check via dmidecode (local)
dmidecode -t 0 | grep -E "Version|Release Date"
```

Note: Unlike Dell systems, BIOS changes on Supermicro via Redfish take effect on the next reboot without requiring a separate job creation step. PATCH `/redfish/v1/Systems/1/Bios/Settings` and then reboot.

---

## Server Component Firmware Hierarchy

A Supermicro server contains multiple independently updatable firmware components. Update order matters — always update the BMC first, then BIOS, then remaining components.

| Component | Update Mechanism | Reboot Required | Typical Update Time |
|---|---|---|---|
| **BMC Firmware** | SUM, Redfish SimpleUpdate, web UI | BMC resets (not host) | 5–10 minutes |
| **BIOS/UEFI** | SUM, Redfish SimpleUpdate, web UI | Yes (host reboot) | 5–10 minutes |
| **CPLD** | SUM, web UI (Maintenance page) | Yes (full AC power cycle) | 2–5 minutes |
| **NIC Firmware** | Vendor tools (e.g., bnxtfw for Broadcom), SUM | Varies | 2–5 minutes per NIC |
| **RAID Controller Firmware** | storcli, SUM | Yes (host reboot) | 5–10 minutes |
| **Drive Firmware** | storcli (SAS/SATA), nvme-cli (NVMe) | Varies | 1–3 minutes per drive |
| **PSU Firmware** | BMC web UI (Maintenance) | No | 5–10 minutes per PSU |

### Recommended Update Order

1. BMC firmware
2. BIOS/UEFI
3. CPLD (if applicable — requires full AC power cycle, schedule carefully)
4. NIC firmware
5. RAID controller firmware
6. Drive firmware
7. PSU firmware

> **CPLD warning:** CPLD updates require a full AC power cycle (not just a reboot). This means physically removing power from the server. Plan for a hard outage window.

### Checking Installed Firmware Versions

```bash
# Full firmware inventory via Redfish
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/UpdateService/FirmwareInventory | \
  jq '.Members[]."@odata.id"'

# Individual component via Redfish (replace <id> with the inventory ID from above)
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/UpdateService/FirmwareInventory/<id> | \
  jq '{Name, Version, Status}'

# BMC firmware version
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Managers/1 | jq '.FirmwareVersion'

# BIOS version via Redfish
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Systems/1/Bios | jq '.Attributes.BiosVersion // .FirmwareVersion'

# BMC and BIOS version via SUM
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c GetBmcInfo
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c GetBiosInfo

# Via ipmitool
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc info
# Look for "Firmware Revision" in the output

# Via dmidecode (local — BIOS only)
dmidecode -s bios-version
dmidecode -s bios-release-date
```

---

## SUM (Supermicro Update Manager) Overview

SUM is Supermicro's proprietary command-line utility for BIOS and BMC management. It is the Supermicro equivalent of Dell's racadm for configuration tasks.

> **Download requirement:** SUM requires a Supermicro account to download from supermicro.com. It is not freely redistributable. Place the archive in `container/` before building the Docker image.

### Key SUM Operations

| Command | Purpose |
|---|---|
| `GetBiosInfo` | Show current BIOS version and available update version |
| `GetBmcInfo` | Show BMC version and available update version |
| `GetCurrentBiosCfg` | Export current BIOS configuration to XML |
| `ChangeBiosCfg` | Import/apply a BIOS configuration from XML |
| `UpdateBios` | Update BIOS to a specified file |
| `UpdateBmc` | Update BMC firmware to a specified file |
| `GetBmcCfg` | Export current BMC configuration |
| `ChangeBmcCfg` | Import/apply BMC configuration |

```bash
# Remote SUM syntax
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c <command> [--file <file>]

# Export BIOS configuration
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c GetCurrentBiosCfg --file bios-export.xml

# Apply BIOS configuration
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c ChangeBiosCfg --file bios-import.xml

# Check BIOS info
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c GetBiosInfo

# Check BMC info
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c GetBmcInfo
```

---

## X11 vs X12 vs X13 Feature Differences

Understanding per-generation capabilities helps when targeting automation to mixed fleets.

| Feature | X11 | X12 | X13 |
|---|---|---|---|
| **Processor** | Xeon SP Gen 1/2 (Skylake/Cascade Lake) | Xeon SP Gen 3 (Ice Lake) | Xeon SP Gen 4/5 (SPR/EMR) |
| **PCIe Generation** | PCIe 3.0 | PCIe 4.0 | PCIe 5.0 |
| **DDR** | DDR4 | DDR4 | DDR5 |
| **Redfish Support** | Partial (some X11 models lack full Redfish) | Full Redfish 1.x | Full Redfish 1.x+ |
| **BIOS via Redfish** | Limited on older BMC | Supported | Supported |
| **NVMe Boot** | Limited | Yes | Yes |
| **Default KVM** | Java (HTML5 optional depending on BMC version) | HTML5 preferred | HTML5 |
| **Node Manager** | v3.x | v4.x | v4.x+ |

> **X11 Redfish caveat:** Some older X11 motherboards with early BMC firmware have incomplete Redfish implementations. If Redfish calls return errors or missing endpoints on X11, fall back to ipmitool and SUM for those operations. Always check the BMC firmware version and update if possible.
