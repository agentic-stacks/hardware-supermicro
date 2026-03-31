# Diagnose: Storage and RAID Issues

Systematic procedures for diagnosing Supermicro server storage failures. Work through the relevant symptom section top-to-bottom. Do not skip steps.

> **Tool Note:** Commands below use `storcli64` for LSI/Broadcom MegaRAID controllers, which are common in Supermicro servers. If your server uses a different controller (e.g., Adaptec, software RAID), substitute the appropriate tool. Run `storcli64 show` to confirm the controller is detected.

---

## Symptom: RAID Array Degraded

### Decision Tree

1. Check overall array status
   ```bash
   storcli64 /c0/vall show
   ```
   Look for virtual drives with state `Dgrd` (Degraded) or `Pdgd` (Partially Degraded).

2. Find the failed or missing physical drive
   ```bash
   storcli64 /c0/eall/sall show
   ```
   Look for drives with state:
   - `Offln` — drive is offline (failed)
   - `UBad` — unconfigured bad (removed or failed outside RAID)
   - `Missing` — was part of array but is not currently detected

3. If the failed drive is still physically present and shows `UBad`:
   ```bash
   # Mark the drive as good so it can be used for rebuild
   storcli64 /c0/e252/s1 set good

   # Start rebuild (replace e252/s1 with the actual enclosure/slot)
   storcli64 /c0/e252/s1 start rebuild
   ```

4. If the drive has been physically replaced, check for auto-rebuild:
   ```bash
   # New drive should appear as UGood (Unconfigured Good)
   storcli64 /c0/eall/sall show

   # If rebuild did not start automatically, start it manually
   storcli64 /c0/e<ENCL>/s<SLOT> start rebuild
   ```

5. Monitor rebuild progress
   ```bash
   storcli64 /c0/eall/sall show rebuild
   ```

6. If a hot spare is configured, rebuild starts automatically upon drive failure — no manual steps needed unless the hot spare is not triggering.

---

## Symptom: Foreign Drive Configuration Detected

Drives from another server or a previous RAID configuration show as "Foreign."

### Decision Tree

```
Foreign drives detected
|
+-- Do you want to preserve data from the source system?
|   +-- Yes --> Import the foreign configuration
|   |   storcli64 /c0/fall show       (inspect what will be imported)
|   |   storcli64 /c0/fall import     (imports config and makes VDs available)
|   |
|   +-- No / drives are blank --> Clear the foreign configuration
|       WARNING: All data on those drives becomes inaccessible
|       storcli64 /c0/fall del
```

### Commands

```bash
# View the foreign configuration (shows what arrays the drives were part of)
storcli64 /c0/fall show

# Import foreign config (preserves existing RAID config and data)
storcli64 /c0/fall import

# Clear foreign config (WARNING: DATA ON THOSE DRIVES BECOMES INACCESSIBLE)
storcli64 /c0/fall del

# After import, verify the virtual drive is online
storcli64 /c0/vall show
```

**WARNING: `storcli64 /c0/fall del` permanently removes the RAID metadata from those drives. All data on the foreign drives will be inaccessible. Only run this if you are certain you do not need the data.**

---

## Symptom: Boot Drive Not Found

### Decision Tree

1. Verify the RAID controller detects the boot virtual drive
   ```bash
   storcli64 /c0/vall show
   ```
   - If VD0 (or boot VD) is `Dgrd` or `Offln` --> go to "RAID Array Degraded" section above
   - If no virtual drives exist --> check physical drives below

2. Check physical drive detection
   ```bash
   storcli64 /c0/eall/sall show
   ```
   - If drives show as `UBad` or `Missing` --> drive(s) may have failed or been removed
   - If no drives listed --> check SAS/SATA cable connections and power to drive backplane

3. Verify boot order in BMC (Redfish)
   ```bash
   curl -sk -u $BMC_USER:$BMC_PASS \
     https://$BMC_HOST/redfish/v1/Systems/1 | jq '.Boot'
   ```

4. Verify the virtual drive is set as the boot device
   ```bash
   storcli64 /c0/v0 show all | grep -i "boot"

   # Set the VD as the boot device if it is not set
   storcli64 /c0/v0 set bootdrive=on
   ```

5. If the VD exists and is online but the OS won't load
   - Boot from rescue/recovery media
   - Check for filesystem corruption on the OS partition
   - The VD may have been initialized (data wiped): `storcli64 /c0/v0 show init`

6. Check RAID controller firmware version — an outdated firmware may cause detection issues
   ```bash
   storcli64 /c0 show | grep -i "firmware\|FW"
   ```

---

## Symptom: Rebuild Stuck or Not Starting

### Decision Tree

1. Check rebuild progress
   ```bash
   storcli64 /c0/eall/sall show rebuild
   ```

2. If progress is 0% and not advancing:
   - Check for errors on the replacement drive: `storcli64 /c0/eall/s<SLOT> show all | grep -i error`
   - The replacement drive may be too small (must be >= original drive capacity)
   - Verify drive size: `storcli64 /c0/eall/sall show all | grep "Raw Size"`
   - Unsupported drive model or sector size mismatch (512n vs 512e vs 4Kn)

3. If progress is moving but very slow:
   - Check rebuild rate: `storcli64 /c0 show rebuildrate`
   - Default is typically 30%. Increase to speed up rebuild (trades I/O performance):
     ```bash
     storcli64 /c0 set rebuildrate=60
     ```
   - Reduce workload on the server during rebuild to free I/O bandwidth

4. Check controller event log for errors during rebuild
   ```bash
   storcli64 /c0 show events | tail -50
   ```

---

## Symptom: Drive Predictive Failure

SMART monitoring or patrol read has flagged a drive as likely to fail.

### Decision Tree

1. Identify the flagged drive
   ```bash
   storcli64 /c0/eall/sall show all | grep -B5 "Predictive"
   ```

2. Check SMART data for the drive
   ```bash
   storcli64 /c0/eall/s<SLOT> show all | grep -A20 "SMART"
   ```
   Key indicators:
   - **Reallocated Sector Count** > 0 — drive is remapping bad sectors
   - **Current Pending Sector** > 0 — sectors waiting to be remapped
   - **Media Error Count** increasing — physical media degradation

3. Plan for replacement
   - If a hot spare is assigned, assign it to the degraded drive group then swap the predicted-failure drive
   - If no hot spare is available, assign one first:
     ```bash
     storcli64 /c0/e<ENCL>/s<SPARE_SLOT> add hotsparedrive dgs=<DG_NUMBER>
     ```
   - Then physically replace the predicted-failure drive — rebuild will start on the hot spare

---

## RAID Controller Reference

### Check controller health

```bash
# Overall controller status
storcli64 /c0 show

# Controller properties (cache policy, rebuild rate, etc.)
storcli64 /c0 show all | grep -E "Rebuild Rate|Cache|BBU|Capacitor"
```

### Check BBU / capacitor status

```bash
storcli64 /c0/cv show all
```

Expected healthy state: `State: Optimal`. If `Failed` or `Degraded`, write-back cache is disabled (performance impact) and the BBU or capacitor module needs replacement.

### Clear controller event log

```bash
storcli64 /c0 delete events
```

---

## Storage Diagnosis Quick Reference

| storcli64 Command | Purpose |
|---|---|
| `storcli64 show` | List all detected controllers |
| `storcli64 /c0/vall show` | Show all virtual drives (arrays) |
| `storcli64 /c0/eall/sall show` | Show all physical drives |
| `storcli64 /c0/eall/sall show rebuild` | Show rebuild progress |
| `storcli64 /c0/fall show` | Show foreign configurations |
| `storcli64 /c0/fall import` | Import foreign config (preserves data) |
| `storcli64 /c0/fall del` | Clear foreign config (DATA LOSS WARNING) |
| `storcli64 /c0/e<E>/s<S> set good` | Mark drive as unconfigured good |
| `storcli64 /c0/e<E>/s<S> start rebuild` | Start manual rebuild |
| `storcli64 /c0/v0 set bootdrive=on` | Set VD0 as boot drive |
| `storcli64 /c0/cv show all` | Check BBU/capacitor status |
| `storcli64 /c0 show rebuildrate` | Check current rebuild rate |
| `storcli64 /c0 set rebuildrate=60` | Set rebuild rate to 60% |
