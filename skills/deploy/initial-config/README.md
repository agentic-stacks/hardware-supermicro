# Initial Configuration

## Purpose

Perform first-time BMC configuration on a new or factory-default Supermicro server: verify access, change the default password, configure BMC networking, set NTP and DNS, optionally configure SNMP, and export a baseline configuration.

> **Supermicro default credentials:** ADMIN / ADMIN (both uppercase). These are publicly known. Change them immediately.

## Prerequisites

| Requirement | How to Verify |
|---|---|
| ipmitool available | `ipmitool -V` or `docker exec smc-tools ipmitool -V` |
| curl and jq available | `curl --version && jq --version` |
| Network path to BMC | `ping -c 3 $BMC_HOST` — 0% packet loss |
| BMC credentials known | Supermicro default: ADMIN / ADMIN |

Set these environment variables before running any commands in this guide:

```bash
export BMC_HOST=192.168.1.100   # BMC IP address
export BMC_USER=ADMIN           # BMC username (default)
export BMC_PASS=ADMIN           # BMC password (default — change in Step 2)
```

If using the container, prefix all commands with `docker exec smc-tools`. The examples below show the direct form; add the prefix as needed.

---

## Step 1: Verify BMC Access

Confirm the BMC is reachable and responding before making any changes.

```bash
# Check BMC is reachable via IPMI
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc info
```

Expected: output showing the Firmware Revision, Manufacturer, and Product Name for the BMC.

```bash
# Check Redfish API is available
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/ | jq '.RedfishVersion'
```

Expected: a version string such as `"1.8.0"`.

### If Access Fails

| Symptom | Likely Cause | Fix |
|---|---|---|
| ipmitool times out | Wrong IP or firewall | Verify IP with `ping $BMC_HOST`; open UDP 623 |
| Authentication error | Wrong credentials | Supermicro default is ADMIN / ADMIN (uppercase) |
| curl SSL error | Self-signed cert | Always use `-sk` for BMC Redfish calls |
| curl connection refused | HTTPS not enabled | Enable via BMC web UI or check port 443 firewall |

---

## Step 2: Change Default Password

> **CRITICAL: DEFAULT CREDENTIALS ARE A SECURITY RISK.**
>
> An attacker with network access to the BMC port can gain full out-of-band hardware control: remote console, power cycling, virtual media mounting, and BIOS modification.
>
> **Change the default password before connecting the BMC to any production or shared network.**

### Change via IPMI

```bash
# User slot 2 is the default ADMIN account on Supermicro BMCs
ipmitool -I lanplus -H $BMC_HOST -U ADMIN -P ADMIN user set password 2 "NewSecurePassword123!"
```

### Change via Redfish

```bash
curl -sk -u ADMIN:ADMIN -X PATCH \
  https://$BMC_HOST/redfish/v1/AccountService/Accounts/2 \
  -H 'Content-Type: application/json' \
  -d '{"Password": "NewSecurePassword123!"}'
```

Notes:
- Choose a password meeting your organisation's complexity requirements (minimum 12 characters, mixed case, numbers, special characters recommended).
- Record the new password in your secrets manager immediately.

### Verify the New Password Works

```bash
ipmitool -I lanplus -H $BMC_HOST -U ADMIN -P "NewSecurePassword123!" mc info
```

Update your environment variable:

```bash
export BMC_PASS="NewSecurePassword123!"
```

**From this point forward, all commands use the new credentials via `$BMC_USER` and `$BMC_PASS`.**

---

## Step 3: Configure BMC Network

Skip this step if the BMC already has the correct static IP assigned.

### View Current Network Configuration

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan print 1
```

Look for the IP Address, Subnet Mask, Default Gateway IP, and IP Address Source lines.

### Set a Static IP

> **WARNING:** Setting the wrong IP, mask, or gateway can make the BMC unreachable. Have console access ready before proceeding.

```bash
# Switch to static addressing
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan set 1 ipsrc static

# Set the static IP address
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan set 1 ipaddr 10.0.10.101

# Set the subnet mask
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan set 1 netmask 255.255.255.0

# Set the default gateway
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan set 1 defgw ipaddr 10.0.10.1
```

After changing the IP, update `$BMC_HOST` and wait 15-30 seconds for the change to apply:

```bash
export BMC_HOST=10.0.10.101
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan print 1
```

---

## Step 4: Configure NTP

Accurate time is required for TLS certificates, log correlation, and Redfish event timestamps.

```bash
curl -sk -u $BMC_USER:$BMC_PASS -X PATCH \
  https://$BMC_HOST/redfish/v1/Managers/1/NetworkProtocol \
  -H 'Content-Type: application/json' \
  -d '{
    "NTP": {
      "NTPServers": ["pool.ntp.org", "time.google.com"],
      "ProtocolEnabled": true
    }
  }'
```

Replace `pool.ntp.org` and `time.google.com` with your organisation's NTP servers if you operate internal time sources.

### Verify NTP Configuration

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Managers/1/NetworkProtocol | jq '.NTP'
```

Expected: `"ProtocolEnabled": true` and the configured server list.

---

## Step 5: Configure DNS

DNS allows the BMC to resolve hostnames for NTP servers, syslog destinations, and LDAP/AD servers.

```bash
curl -sk -u $BMC_USER:$BMC_PASS -X PATCH \
  https://$BMC_HOST/redfish/v1/Managers/1/EthernetInterfaces/1 \
  -H 'Content-Type: application/json' \
  -d '{"NameServers": ["8.8.8.8", "8.8.4.4"]}'
```

Replace the DNS server IPs with your organisation's DNS resolvers.

### Verify DNS Configuration

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Managers/1/EthernetInterfaces/1 | jq '.NameServers'
```

---

## Step 6: Configure SNMP (Optional)

Configure SNMP only if your monitoring infrastructure uses SNMP traps for hardware alerts. Skip this step if you use Redfish event subscriptions or another alerting mechanism.

```bash
# Set SNMP community string for IPMI channel 1
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan set 1 snmp public
```

Replace `public` with your organisation's SNMP community string.

### Verify SNMP

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS lan print 1 | grep -i snmp
```

---

## Step 7: Export Baseline Configuration

Export the current BMC and BIOS configuration immediately after initial setup. This establishes a known-good baseline for drift detection and disaster recovery.

> **Note:** The exported files may contain sensitive information (network config, user references). Store them in a secure location. Do not commit them to public repositories.

### Export BIOS Configuration via Redfish

```bash
mkdir -p workspace/configs

curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/Bios \
  | jq '.Attributes' > workspace/configs/$(hostname)-bios-baseline.json
```

### Export BMC Configuration via Redfish

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Managers/1 \
  | jq '.' > workspace/configs/$(hostname)-bmc-baseline.json
```

### Export via SUM (if SUM is installed)

SUM produces a complete BIOS configuration XML that can be used to restore settings or apply them to identical servers:

```bash
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS \
  -c GetCurrentBiosCfg \
  --file workspace/configs/$(hostname)-bios-baseline.xml
```

### Commit the Baseline

```bash
cd workspace/configs
git add .
git commit -m "chore: baseline config export for $(hostname)"
```

---

## Step 8: Verify

Run these commands to confirm the completed configuration. All checks should return valid data.

### System Information

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1 \
  | jq '{Model, SerialNumber, PowerState, BiosVersion}'
```

Expected: populated model, serial number, power state (On or Off), and BIOS version string.

### BMC Firmware Version

```bash
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Managers/1 \
  | jq '{FirmwareVersion}'
```

### Sensor Health

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS sdr list | head -20
```

Expected: a list of sensors with status values. Healthy sensors show `ok`; any `cr` (critical) or `nr` (non-recoverable) entries require investigation.

---

## Completion Checklist

| Step | Verification Command | Expected Result |
|---|---|---|
| BMC reachable | `ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc info` | Firmware Revision and Product Name shown |
| Redfish available | `curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/ \| jq '.RedfishVersion'` | Version string returned |
| Password changed | `ipmitool ... mc info` with new password | Succeeds without auth error |
| Network configured | `ipmitool ... lan print 1` | Correct IP, mask, gateway shown |
| NTP enabled | `curl ... /Managers/1/NetworkProtocol \| jq '.NTP'` | ProtocolEnabled true, servers set |
| DNS configured | `curl ... /EthernetInterfaces/1 \| jq '.NameServers'` | DNS IPs shown |
| Baseline exported | `ls workspace/configs/` | JSON/XML baseline files present |
| Baseline committed | `git log workspace/configs/` | Commit exists |

---

## Next Steps

Initial configuration is complete. Proceed to the next phase of the agentic stack — for example, BIOS tuning, RAID configuration, firmware updates, or OS deployment.
