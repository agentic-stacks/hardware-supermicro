# BMC Configuration Management

Supermicro BMC (Baseboard Management Controller) — also called IPMI or IPMI 2.0 — is managed via ipmitool (IPMI over LAN), Redfish API (all X11 with updated firmware, all X12/X13), and SMCIPMITool. Redfish is preferred for new automation; ipmitool is preferred for quick operational tasks.

## BMC Info

### Via IPMI

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc info
```

Output includes: Device ID, firmware revision, IPMI version, manufacturer ID, and product ID.

### Via Redfish

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Managers/1 | jq '{FirmwareVersion, Model, Status}'
```

### Full Redfish manager details

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Managers/1 | jq '{
    FirmwareVersion,
    Model,
    Status,
    NetworkProtocol: .Links.NetworkProtocol,
    DateTime,
    DateTimeLocalOffset
  }'
```

### Check IPMI firmware version only

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc info | grep "Firmware Revision"
```

## User Management

### List all IPMI users

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS user list
```

Output shows user ID, username, enabled/disabled state, and privilege level. Supermicro BMC supports up to 10 user slots.

### View user privilege levels

IPMI privilege levels:

| Level | Value | Description |
|-------|-------|-------------|
| Callback | 1 | Lowest — limited to callback operations |
| User | 2 | Read-only access to most commands |
| Operator | 3 | Most commands except config changes |
| Administrator | 4 | Full access — required for most management tasks |
| OEM | 5 | Vendor-specific extensions |

### Create a new user via IPMI

```bash
# Set username for slot 3
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS user set name 3 newadmin

# Set password
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS user set password 3 "SecureP@ss123"

# Enable the user
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS user enable 3

# Set channel 1 (LAN) access with Administrator privilege
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS channel setaccess 1 3 callin=on ipmi=on link=on privilege=4
```

### Disable a user

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS user disable 3
```

### Change a user's password

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS user set password 3 "NewSecureP@ss456"
```

### Create a user via Redfish

```bash
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/AccountService/Accounts \
  -H 'Content-Type: application/json' \
  -d '{
    "UserName": "newadmin",
    "Password": "SecureP@ss123",
    "RoleId": "Administrator",
    "Enabled": true
  }'
```

Valid `RoleId` values: `Administrator`, `Operator`, `ReadOnlyUser`, `None`

### List accounts via Redfish

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/AccountService/Accounts | jq '.Members[]'
```

### Modify a Redfish account

```bash
# Get the account ID first
ACCOUNT_ID=$(curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/AccountService/Accounts | \
  jq -r '.Members[] | @uri' | xargs -I{} curl -sk -u $BMC_USER:$BMC_PASS \
  "https://$BMC_HOST{}" | jq -r 'select(.UserName=="newadmin") | .Id')

# Change password
curl -sk -u $BMC_USER:$BMC_PASS -X PATCH \
  https://$BMC_HOST/redfish/v1/AccountService/Accounts/$ACCOUNT_ID \
  -H 'Content-Type: application/json' \
  -d '{"Password": "UpdatedP@ss789"}'

# Disable account
curl -sk -u $BMC_USER:$BMC_PASS -X PATCH \
  https://$BMC_HOST/redfish/v1/AccountService/Accounts/$ACCOUNT_ID \
  -H 'Content-Type: application/json' \
  -d '{"Enabled": false}'
```

## Power Control

### Check power status

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power status
```

### Power actions via IPMI

```bash
# Power on the server
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power on

# Graceful shutdown (ACPI signal to OS — waits for OS to shut down cleanly)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power soft

# Hard power off (immediate — no OS signal, risk of filesystem corruption)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power off

# Power cycle (hard off, then on)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power cycle

# Hard reset (warm reboot — no graceful OS shutdown)
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power reset
```

> **WARNING:** `power off` and `power cycle` are non-graceful. Use `power soft` when the OS is running to avoid filesystem corruption. Use `power off` / `power cycle` only when the OS is unresponsive or the server is powered off.

### Power actions via Redfish

```bash
# Power on
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "On"}'

# Graceful shutdown (OS shuts down, server powers off)
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "GracefulShutdown"}'

# Graceful reboot (OS shuts down, server reboots)
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "GracefulRestart"}'

# Force off (immediate power cut — no OS signal)
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "ForceOff"}'

# Force restart (hard reset — no OS shutdown)
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "ForceRestart"}'
```

Redfish `ResetType` options:

| ResetType | Effect |
|-----------|--------|
| `On` | Power on (from powered-off state) |
| `ForceOn` | Force power on |
| `GracefulShutdown` | ACPI shutdown signal, host powers off |
| `GracefulRestart` | ACPI shutdown, then reboot |
| `ForceOff` | Immediate power cut — non-graceful |
| `ForceRestart` | Hard reset — non-graceful |
| `PushPowerButton` | Simulate front-panel power button press |

### Check power consumption

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Chassis/1/Power | jq '.PowerControl[0] | {PowerConsumedWatts, PowerCapacityWatts}'
```

## Alert Configuration (SNMP)

### Configure SNMP community string via IPMI

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan set 1 snmp public
```

### Configure SNMP trap destination via IPMI

```bash
# Enable alert on channel 1 destination 1
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan alert set 1 1 ipaddr 192.168.1.50
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan alert set 1 1 petacknowledge
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan alert set 1 1 enabled
```

### View current SNMP/LAN alert configuration

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan alert print 1
```

### Configure SNMP via Redfish

```bash
curl -sk -u $BMC_USER:$BMC_PASS -X PATCH \
  https://$BMC_HOST/redfish/v1/Managers/1/NetworkProtocol \
  -H 'Content-Type: application/json' \
  -d '{
    "SNMP": {
      "ProtocolEnabled": true,
      "Port": 161,
      "TrapPort": 162,
      "CommunityAccessControl": "Full"
    }
  }'
```

## Syslog Forwarding

### Configure syslog forwarding via Redfish

```bash
curl -sk -u $BMC_USER:$BMC_PASS -X PATCH \
  https://$BMC_HOST/redfish/v1/Managers/1/NetworkProtocol \
  -H 'Content-Type: application/json' \
  -d '{
    "Syslog": {
      "SyslogServers": ["192.168.1.50"],
      "ProtocolEnabled": true
    }
  }'
```

### Configure multiple syslog destinations

```bash
curl -sk -u $BMC_USER:$BMC_PASS -X PATCH \
  https://$BMC_HOST/redfish/v1/Managers/1/NetworkProtocol \
  -H 'Content-Type: application/json' \
  -d '{
    "Syslog": {
      "SyslogServers": ["192.168.1.50", "192.168.1.51"],
      "ProtocolEnabled": true
    }
  }'
```

### Verify syslog configuration

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Managers/1/NetworkProtocol | jq '.Syslog'
```

## System Event Log (SEL)

The SEL records hardware events such as temperature thresholds crossed, fan failures, memory errors, and power supply events.

### View SEL entries via IPMI

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel list
```

### SEL summary info (capacity, timestamps)

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel info
```

### Get most recent SEL entries

```bash
# Last 20 entries
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel list last 20
```

### Clear the SEL

> **WARNING:** `sel clear` permanently deletes all event history from the log. Export to a file before clearing if historical records are needed for compliance or post-mortem.

```bash
# Export first
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel save sel-export-$(date +%Y%m%d).txt

# Then clear
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sel clear
```

### View SEL via Redfish

```bash
# List recent log entries
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Managers/1/LogServices/Log1/Entries | \
  jq '.Members[] | {Created, Message, Severity}'
```

### Filter SEL by severity via Redfish

```bash
# Critical events only
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Managers/1/LogServices/Log1/Entries | \
  jq '.Members[] | select(.Severity == "Critical") | {Created, Message}'

# Warning and above
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Managers/1/LogServices/Log1/Entries | \
  jq '.Members[] | select(.Severity == "Warning" or .Severity == "Critical") | {Created, Message, Severity}'
```

### Clear SEL via Redfish

```bash
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Managers/1/LogServices/Log1/Actions/LogService.ClearLog \
  -H 'Content-Type: application/json' -d '{}'
```

## KVM Console and Virtual Media

### Open KVM console

The KVM console is accessed via the BMC web UI (`https://$BMC_HOST`) or via IKVM client. Supermicro provides an HTML5 KVM viewer on X12/X13. For X11, use the Java IKVM client or IPMIView.

```bash
# Open BMC web interface (requires browser)
echo "KVM console: https://$BMC_HOST"
```

### Mount virtual media via Redfish (X12/X13)

```bash
# Insert an ISO image as virtual CD
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Managers/1/VirtualMedia/CD1/Actions/VirtualMedia.InsertMedia \
  -H 'Content-Type: application/json' \
  -d '{"Image": "http://192.168.1.10/images/ubuntu-24.04-live-server-amd64.iso"}'
```

The `Image` URL must be accessible from the BMC's network interface. HTTP and HTTPS are supported; NFS is not.

### Check virtual media status

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Managers/1/VirtualMedia/CD1 | \
  jq '{Inserted, Image, ConnectedVia, MediaTypes}'
```

### Eject virtual media

```bash
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Managers/1/VirtualMedia/CD1/Actions/VirtualMedia.EjectMedia \
  -H 'Content-Type: application/json' -d '{}'
```

### List available virtual media slots

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Managers/1/VirtualMedia | jq '.Members[]'
```

### Boot from virtual CD (next boot only)

```bash
# Set one-time boot to CD via IPMI
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis bootdev cdrom options=efiboot

# Then power cycle to start booting from virtual CD
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power cycle
```

## BMC Reset

### Warm reset (preserves configuration, restarts BMC services)

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc reset warm
```

> **WARNING:** A warm BMC reset interrupts all active IPMI and Redfish management sessions. The host OS is not affected. The BMC will be unreachable for 1-3 minutes while it restarts.

### Cold reset (full BMC hardware restart)

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc reset cold
```

> **WARNING:** A cold reset performs a full BMC hardware restart. More disruptive than warm reset. The BMC will be unreachable for 2-5 minutes. The host OS is not affected, but power control and monitoring are suspended during the reset.

### BMC reset via Redfish

```bash
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Managers/1/Actions/Manager.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "GracefulRestart"}'
```

### Wait for BMC to come back online after reset

```bash
echo "Waiting for BMC to come back online..."
until ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc info &>/dev/null; do
  sleep 10
  echo "Still waiting..."
done
echo "BMC is back online."
```

## BMC Network Configuration

### View current LAN configuration

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan print 1
```

Shows: IP address, subnet mask, default gateway, MAC address, VLAN ID, DHCP/static mode.

### View network config via Redfish

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Managers/1/EthernetInterfaces | jq '.Members[]'

curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Managers/1/EthernetInterfaces/bond0 | \
  jq '{MACAddress, IPv4Addresses, IPv6Addresses, VLAN}'
```

### Set static IP via IPMI

> **WARNING:** Changing the BMC IP address will immediately sever your current IPMI/Redfish connection. Ensure you have physical access or an alternative connection before changing the IP.

```bash
# Disable DHCP
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan set 1 ipsrc static

# Set IP address
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan set 1 ipaddr 192.168.1.101

# Set subnet mask
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan set 1 netmask 255.255.255.0

# Set default gateway
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan set 1 defgw ipaddr 192.168.1.1
```

### Enable DHCP

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan set 1 ipsrc dhcp
```

### Configure VLAN tagging

```bash
# Enable VLAN and set VLAN ID
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan set 1 vlan id 100

# Verify VLAN is set
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan print 1 | grep -i vlan
```

### Remove VLAN (return to untagged)

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan set 1 vlan id off
```

### Configure network via Redfish

```bash
curl -sk -u $BMC_USER:$BMC_PASS -X PATCH \
  https://$BMC_HOST/redfish/v1/Managers/1/EthernetInterfaces/bond0 \
  -H 'Content-Type: application/json' \
  -d '{
    "DHCPv4": {"DHCPEnabled": false},
    "IPv4StaticAddresses": [
      {
        "Address": "192.168.1.101",
        "SubnetMask": "255.255.255.0",
        "Gateway": "192.168.1.1"
      }
    ]
  }'
```

### Set NTP server

```bash
curl -sk -u $BMC_USER:$BMC_PASS -X PATCH \
  https://$BMC_HOST/redfish/v1/Managers/1/NetworkProtocol \
  -H 'Content-Type: application/json' \
  -d '{
    "NTP": {
      "ProtocolEnabled": true,
      "NTPServers": ["192.168.1.1", "pool.ntp.org"]
    }
  }'
```

### Verify NTP configuration

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Managers/1/NetworkProtocol | jq '.NTP'
```
