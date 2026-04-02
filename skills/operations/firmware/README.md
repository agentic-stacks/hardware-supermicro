# Firmware Management

## Check Current Firmware Versions

```bash
# BMC firmware version via IPMI
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc info

# All firmware components via Redfish
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/UpdateService/FirmwareInventory | jq '.Members[]'

# Specific component versions
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/UpdateService/FirmwareInventory/BMC | jq '{Name, Version}'

curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/UpdateService/FirmwareInventory/BIOS | jq '{Name, Version}'
```

---

## Firmware Update Order

> **CRITICAL:** Always update firmware in this order. Updating out of order can cause compatibility issues or failed updates.

1. **BMC firmware** — BMC resets after update; host is unaffected
2. **BIOS/UEFI** — requires host reboot to apply
3. **CPLD** — requires full AC power cycle after update
4. **NIC firmware**
5. **RAID controller firmware**
6. **Drive firmware**

---

## Update BMC Firmware via Redfish

```bash
# Upload and flash BMC firmware via SimpleUpdate
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/UpdateService/Actions/UpdateService.SimpleUpdate \
  -H 'Content-Type: application/json' \
  -d '{"ImageURI": "http://192.168.1.10/firmware/BMC_X13AST2600-ROT-1201MS_20240815_01.09.02_STDsp.bin", "TransferProtocol": "HTTP"}'

# Monitor update progress
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/TaskService/Tasks | jq '.Members[]'
```

The BMC will reset automatically once the update completes. Wait for it to come back online before proceeding.

---

## Update BMC Firmware via SUM

Supermicro Update Manager (SUM) provides an alternative out-of-band update path.

```bash
# Check OOB update support
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c CheckOOBSupport

# Update BMC firmware
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c UpdateBmc --file BMC_firmware.bin

# Update BIOS firmware (--reboot triggers reboot to apply)
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c UpdateBios --file BIOS_firmware.bin --reboot
```

---

## Update BIOS Firmware via Redfish

```bash
# Upload BIOS firmware via SimpleUpdate
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/UpdateService/Actions/UpdateService.SimpleUpdate \
  -H 'Content-Type: application/json' \
  -d '{"ImageURI": "http://192.168.1.10/firmware/BIOS_X13DEM-Q24-G1M1_20240920_1.3_STDsp.bin"}'

# Reboot to apply BIOS update
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/Systems/1/Actions/ComputerSystem.Reset \
  -H 'Content-Type: application/json' \
  -d '{"ResetType": "GracefulRestart"}'
```

---

## Downloading Firmware

Supermicro firmware is distributed through the Supermicro support portal:

1. Navigate to [supermicro.com](https://www.supermicro.com) → Support → Download Center
2. Select your motherboard or server model
3. Download BMC, BIOS, and component firmware packages separately
4. Some files require a registered account

Always verify checksums before flashing:

```bash
# Verify SHA256 checksum against the published value
sha256sum BMC_firmware.bin
```

Store firmware files in `workspace/firmware/` with version numbers in the filename (e.g., `BMC_X13_01.09.02.bin`) so older versions are easy to identify for rollback.

---

## Rollback

Supermicro BMC typically stores a backup firmware image in a secondary flash partition. If a BMC update fails mid-flash, the backup image boots automatically.

For manual rollback:

```bash
# Reflash a previous BMC version using the same SimpleUpdate method
curl -sk -u $BMC_USER:$BMC_PASS -X POST \
  https://$BMC_HOST/redfish/v1/UpdateService/Actions/UpdateService.SimpleUpdate \
  -H 'Content-Type: application/json' \
  -d '{"ImageURI": "http://192.168.1.10/firmware/BMC_previous_version.bin", "TransferProtocol": "HTTP"}'

# Reflash a previous BIOS version via SUM
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c UpdateBios --file BIOS_previous_version.bin --reboot
```

> **Note:** Keep versioned firmware files in `workspace/firmware/` so previous versions are always available for rollback.

---

## SUM Batch Updates

Update multiple servers in a single operation using a server list file:

```bash
# Update BMC firmware across a list of servers
sum -l server_list.txt -u $BMC_USER -p $BMC_PASS -c UpdateBmc --file BMC_firmware.bin

# Update BIOS across a list of servers
sum -l server_list.txt -u $BMC_USER -p $BMC_PASS -c UpdateBios --file BIOS_firmware.bin --reboot
```

`server_list.txt` contains one BMC IP address per line:

```
192.168.1.101
192.168.1.102
192.168.1.103
```
