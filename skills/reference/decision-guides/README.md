# Decision Guides

## ipmitool vs Redfish vs SUM

| Criteria | ipmitool | Redfish API | SUM |
|---|---|---|---|
| Setup complexity | Low — standard package on most distros | Low — curl + jq | Medium — download per-platform version from supermicro.com |
| BIOS config | No | Yes (X12/X13 only) | Yes |
| Firmware updates | No | Yes (X12/X13 only) | Yes |
| Power control | Yes | Yes | Limited |
| Sensor monitoring | Yes | Yes | No |
| Fleet automation | Via Ansible | Via Ansible | Built-in batch mode |
| Vendor-agnostic | Yes | Mostly | No — Supermicro only |

### Recommendation by Use Case

- **Quick power or sensor check** — ipmitool
- **BIOS configuration** — Redfish (X12/X13) or SUM (all platforms including X11)
- **Firmware updates** — SUM (simplest) or Redfish (most modern, X12/X13 only)
- **Fleet automation** — Ansible with Redfish modules
- **Legacy X11 management** — ipmitool + SUM (Redfish too limited on X11)

---

## RAID Level Selection

| Use Case | Recommended Level | Why |
|---|---|---|
| OS boot drive (2 drives) | RAID 1 | Simple mirror, fast rebuild, minimal complexity |
| General storage (3–8 drives) | RAID 5 | Good balance of capacity and protection |
| Large arrays (8+ drives) | RAID 6 | Tolerates 2 simultaneous drive failures |
| Database (4+ drives) | RAID 10 | Best random I/O performance |
| Software-defined storage (Ceph, ZFS) | JBOD / HBA passthrough | Let the software manage redundancy |
| Scratch / temp data | RAID 0 | Maximum performance, no protection needed |

---

## Container vs Bare-Metal Installation

| Factor | Container | Bare Metal |
|---|---|---|
| Setup time | ~5 min (docker build) | ~15 min (manual install) |
| Reproducibility | Exact — Dockerfile is pinned | Varies by OS and package versions |
| OS compatibility | Any — requires Docker | RHEL / Rocky / Ubuntu |
| Local hardware access | Requires privileged mode | Native |
| Team consistency | Identical across workstations | Depends on individual setup |

### Recommendation

Use **container** for teams and reproducibility — the Dockerfile ensures everyone runs the same tool versions. Use **bare metal** on the managed servers themselves (where Docker may not be available) or when privileged container mode is not permitted by policy.
