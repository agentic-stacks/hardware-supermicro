# Diagnose: BMC and Network Connectivity

Systematic procedures for diagnosing Supermicro BMC reachability and network issues. Work through the relevant symptom section top-to-bottom. Do not skip steps.

---

## Symptom: BMC Unreachable

### Decision Tree

```
BMC not responding to ping
|
+-- Check physical network
|   +-- BMC NIC link LED? (solid/blinking = connected, off = no link)
|   +-- Correct port? (dedicated BMC port vs shared LOM)
|   |   Supermicro dedicated BMC port is typically labeled "IPMI" on the rear panel
|   +-- Switch port up? VLAN correct for management network?
|
+-- Check IP configuration
|   +-- If physical access is available:
|   |   Press DEL during POST --> BMC settings --> verify IP address, subnet, gateway
|   |   Or use BIOS setup to access IPMI LAN settings
|   +-- If another BMC on the same network is working:
|       Check ARP table for the expected MAC address
|       arp -a | grep <expected-mac>
|
+-- Check IPMI service
|   +-- Try IPMI port 623 (UDP): nmap -sU -p 623 $BMC_HOST
|   +-- Try HTTPS port 443: curl -sk https://$BMC_HOST/redfish/v1/
|   +-- Both fail --> BMC may need reset via physical jumper or AC power cycle
|
+-- Physical reset options (last resort)
    +-- AC power cycle: disconnect all power cables for 30 seconds, reconnect
    +-- BMC reset jumper: consult the motherboard manual for jumper location
        Most X11/X12/X13 boards have a dedicated BMC reset jumper near the BMC chip
```

### Commands

```bash
# Check basic reachability
ping -c 3 $BMC_HOST

# Check ARP table (confirms L2 connectivity even if ping is blocked)
arp -n | grep $BMC_HOST

# Test IPMI port (UDP 623)
nmap -sU -p 623 $BMC_HOST

# Test Redfish endpoint
curl -sk https://$BMC_HOST/redfish/v1/

# Try IPMI command as connectivity test
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis status
```

---

## Symptom: IPMI Authentication Failures

### Decision Tree

1. Verify credentials
   ```bash
   # Test with current credentials
   ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis status
   ```

2. Try Supermicro default credentials (if credentials may have been reset)
   ```bash
   ipmitool -I lanplus -H $BMC_HOST -U ADMIN -P ADMIN power status
   ```
   - Supermicro default credentials: username `ADMIN`, password `ADMIN`
   - Some boards ship with the password set to the last 8 characters of the board serial number

3. If locked out after failed attempts, wait 5 minutes for the lockout to clear

4. If credentials are unknown and default does not work
   - Physical access is required to reset BMC credentials
   - Use the BMC reset jumper on the motherboard (clears BMC config including passwords, consult board manual for jumper location and procedure)
   - After reset, default credentials are restored

5. Reset BMC user credentials via IPMI (if you have working access with any account)
   ```bash
   # List IPMI users
   ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS user list

   # Set password for user ID 2 (typically ADMIN)
   ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS user set password 2 <new-password>
   ```

---

## Symptom: Redfish API Errors

### Common HTTP Status Codes

| Code | Meaning | Action |
|---|---|---|
| 200 OK | Request succeeded | Normal response |
| 201 Created | Resource created successfully | Normal for POST requests |
| 204 No Content | Action succeeded with no response body | Normal for some PATCH/DELETE |
| 400 Bad Request | Malformed request or invalid parameter | Check request body syntax and parameter names |
| 401 Unauthorized | Authentication failed | Verify BMC_USER and BMC_PASS |
| 403 Forbidden | Authenticated but insufficient privileges | Use Administrator-role account |
| 404 Not Found | Resource does not exist | Check the endpoint URI; some features not available on X11 |
| 405 Method Not Allowed | HTTP method not supported for this endpoint | Check Redfish schema for allowed methods |
| 409 Conflict | Operation conflicts with current state | Server may need to be in correct power state (e.g., off for BIOS config) |
| 500 Internal Server Error | BMC internal error | Check BMC firmware version; try again after a few seconds |
| 503 Service Unavailable | BMC busy or restarting | Wait 30–60 seconds and retry; BMC may be applying a firmware update |

### Debugging a Redfish Request

```bash
# Add -v to curl for full HTTP headers and response
curl -sk -v -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1

# Check what Redfish version and features the BMC advertises
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/ | jq '{RedfishVersion, Name}'

# Check the service root for available endpoints
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/ | jq 'keys'
```

---

## Symptom: BMC Web UI Inaccessible

### Decision Tree

1. Verify HTTPS port 443 is open
   ```bash
   nc -zv $BMC_HOST 443
   # or
   curl -sk https://$BMC_HOST/redfish/v1/
   ```

2. If port 443 is open but browser shows TLS error
   - Supermicro BMC uses a self-signed certificate by default
   - Bypass certificate warning in browser, or use `-sk` with curl
   - For production, install a signed certificate via the BMC web UI or Redfish

3. If port 443 is open but web UI shows error or blank page
   - BMC web service may have hung
   - Reset the BMC web service: `ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc reset warm`
   - Wait 60 seconds and retry

4. If port 443 is closed but IPMI (port 623) is open
   - BMC is alive but HTTPS is not running
   - Cold reset the BMC: `ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc reset cold`
   - Wait 90 seconds for BMC to fully restart

---

## Required Ports Reference

| Port | Protocol | Service | Direction |
|---|---|---|---|
| 443 | TCP | HTTPS (web UI, Redfish API) | Mgmt --> BMC |
| 623 | UDP | IPMI over LAN | Mgmt --> BMC |
| 22 | TCP | SSH (if enabled) | Mgmt --> BMC |
| 5900 | TCP | VNC / HTML5 KVM console | Mgmt --> BMC |
| 80 | TCP | HTTP (typically redirects to 443) | Mgmt --> BMC |
| 162 | UDP | SNMP traps | BMC --> Trap receiver |
| 25/587 | TCP | SMTP (email alerts) | BMC --> Mail server |
| 514 | UDP/TCP | Syslog | BMC --> Syslog server |

---

## BMC Network Configuration Reference

Supermicro BMCs support three NIC modes:

| Mode | Description | When to Use |
|---|---|---|
| Dedicated | BMC uses the dedicated IPMI port only | Preferred for production — fully isolated management network |
| Shared | BMC shares LOM port 1 with the host OS | Use when no dedicated BMC port is connected |
| Failover | Dedicated port primary, fails over to LOM | Use when dedicated port is intermittently unavailable |

To check or change the NIC mode via Redfish:

```bash
# Check current NIC mode
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Managers/1/EthernetInterfaces | jq '.Members'

# View a specific interface
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Managers/1/EthernetInterfaces/1 | \
  jq '{Id, MACAddress, IPv4Addresses, LinkStatus}'
```
