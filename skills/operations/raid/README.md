# RAID Management

## Identify Storage Controller Type

Before running any RAID commands, determine which controller type is installed. Using the wrong tool produces confusing errors.

```bash
# Via lspci (local)
lspci | grep -i raid
lspci | grep -i "MegaRAID\|LSI\|Broadcom"
lspci | grep -i "SATA\|AHCI"

# Via Redfish
curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1/Storage | jq '.Members[]'
```

### Controller Types on Supermicro Servers

| Controller | CLI Tool | Common Models | Use Case |
|---|---|---|---|
| Broadcom MegaRAID | storcli64 | 9460, 9560, 9670 | Hardware RAID |
| Broadcom HBA (IT mode) | storcli64 | 9400, 9500 HBA | Passthrough for ZFS/Ceph |
| Intel VROC | mdadm + VROC key | Built into Xeon | NVMe RAID |
| Onboard SATA | mdadm or BIOS RAID | Intel PCH | Basic boot RAID |

---

## storcli: MegaRAID Management

### View Controller and Drive Status

```bash
# Show all controllers
storcli64 show

# Show controller 0 details
storcli64 /c0 show all

# List virtual drives
storcli64 /c0/vall show

# List physical drives
storcli64 /c0/eall/sall show

# Physical drive details (enclosure 252, slot 0)
storcli64 /c0/e252/s0 show all
```

### Create a Virtual Drive

> **WARNING: VERIFY YOU ARE TARGETING THE CORRECT CONTROLLER AND DRIVES.** Creating a virtual drive on the wrong physical drives can cause data loss.

```bash
# RAID 1 (mirror) with 2 drives
storcli64 /c0 add vd r1 drives=252:0,252:1

# RAID 5 with 3 drives
storcli64 /c0 add vd r5 drives=252:0,252:1,252:2

# RAID 6 with 4 drives
storcli64 /c0 add vd r6 drives=252:0,252:1,252:2,252:3

# RAID 10 with 4 drives
storcli64 /c0 add vd r10 drives=252:0,252:1,252:2,252:3
```

### Delete a Virtual Drive

> **WARNING: DESTRUCTIVE — ALL DATA ON THIS VIRTUAL DRIVE WILL BE PERMANENTLY LOST.** Export any needed data before proceeding. This action cannot be undone.

```bash
# Delete virtual drive 0 on controller 0
storcli64 /c0/v0 del
```

### Hot Spare Management

```bash
# Assign a global hot spare
storcli64 /c0/e252/s4 add hotsparedrive

# Assign a dedicated hot spare for disk group 0
storcli64 /c0/e252/s4 add hotsparedrive dgs=0
```

### Consistency Check and Rebuild

```bash
# Start consistency check on virtual drive 0
storcli64 /c0/v0 start cc

# Check rebuild progress across all drives
storcli64 /c0/eall/sall show rebuild

# Start manual rebuild on a specific drive
storcli64 /c0/e252/s1 start rebuild
```

### Drive SMART Data

```bash
# Show SMART data for a specific drive
storcli64 /c0/e252/s0 show smart
```

---

## HBA / IT Mode (Passthrough)

Used when the OS manages storage directly (ZFS, Ceph, software RAID). No virtual drives are created on the controller.

```bash
# Verify controller mode
storcli64 /c0 show | grep "Controller Mode"

# Set JBOD mode — individual drives visible to OS
storcli64 /c0 set jbod=on

# Create JBOD from a specific drive
storcli64 /c0/e252/s0 set jbod
```

> **Note:** Flashing to full IT mode firmware is a one-way operation on some controllers. Download the IT mode firmware from Broadcom and follow controller-specific instructions.

---

## Intel VROC (Virtual RAID on CPU)

Intel VROC enables NVMe RAID using CPU-integrated logic on Xeon platforms. Key points:

- Requires a VROC hardware key (sold separately; key type determines supported RAID levels)
- Managed via `mdadm` with VROC-aware kernel modules
- Common configurations: RAID 0/1/5/10 for NVMe boot and data drives
- Enable VROC in BIOS under Advanced → PCIe/PCI/PnP before configuring arrays

---

## RAID Level Selection Guide

| RAID Level | Min Drives | Usable Capacity | Fault Tolerance | Best For |
|---|---|---|---|---|
| RAID 0 | 2 | 100% | None | Scratch/temp data, max throughput |
| RAID 1 | 2 | 50% | 1 drive | OS/boot mirrors |
| RAID 5 | 3 | (N-1)/N | 1 drive | General storage, balanced |
| RAID 6 | 4 | (N-2)/N | 2 drives | Large arrays, compliance workloads |
| RAID 10 | 4 | 50% | 1 per mirror | Databases, high IOPS |
