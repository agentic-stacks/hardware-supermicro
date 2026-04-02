# Supermicro Hardware — Agentic Stack

An [agentic stack](https://github.com/agentic-stacks/agentic-stacks) that teaches AI agents to manage Supermicro server hardware — BMC configuration, BIOS management, RAID setup, firmware updates, and hardware inventory.

Includes a container-based toolkit (ipmitool, SUM, SMCIPMITool, storcli, Ansible Redfish) so operators can manage Supermicro servers from any OS without local tool installation.

## Supported Hardware

- **X11** — Xeon Scalable Gen 1/2 (X11DPH-T, X11SPL-F, X11SSH-F, etc.)
- **X12** — Xeon Scalable Gen 3 (X12DPL-NT6, X12SPL-F, X12STL-F, etc.)
- **X13** — Xeon Scalable Gen 4/5 (X13DEM, X13SEL-F, X13SRA-TF, etc.)

## Quick Start

```bash
# Clone the stack
git clone https://github.com/agentic-stacks/hardware-supermicro.git
cd hardware-supermicro

# Set up credentials
cp .env.example .env
# Edit .env with your BMC IP, username, and password

# Build the container (Rocky 9 default)
docker compose -f container/docker-compose.yaml build

# Or build with Rocky 10
docker compose -f container/docker-compose.yaml build --build-arg ROCKY_VERSION=10

# Start the container (privileged mode for local hardware access)
docker compose -f container/docker-compose.yaml up -d smc-tools

# Or remote-only mode (no host hardware passthrough)
docker compose -f container/docker-compose.yaml --profile remote up -d smc-tools-remote

# Run a command
docker exec smc-tools ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS chassis status
```

## What's Inside

### Container Tools

| Tool | Purpose |
|---|---|
| ipmitool | IPMI standard protocol CLI |
| curl / jq | Redfish API calls and JSON processing |
| SUM (Supermicro Update Manager) | Firmware and BIOS config management |
| SMCIPMITool | Supermicro's enhanced IPMI CLI |
| storcli | Broadcom MegaRAID controller management |
| dmidecode, lshw, lspci | Local hardware discovery |
| Ansible + community.general | Fleet-wide server management via Redfish |

### Skills (17)

| Phase | Skills |
|---|---|
| **Foundation** | [Concepts](skills/foundation/concepts), [Tools](skills/foundation/tools), [Architecture](skills/foundation/architecture) |
| **Deploy** | [Container Setup](skills/deploy/container-setup), [Initial Config](skills/deploy/initial-config) |
| **Operations** | [BIOS](skills/operations/bios), [BMC](skills/operations/bmc), [RAID](skills/operations/raid), [Firmware](skills/operations/firmware), [Inventory](skills/operations/inventory), [Ansible](skills/operations/ansible) |
| **Diagnose** | [Hardware](skills/diagnose/hardware), [Connectivity](skills/diagnose/connectivity), [Storage](skills/diagnose/storage) |
| **Reference** | [Known Issues](skills/reference/known-issues), [Compatibility](skills/reference/compatibility), [Decision Guides](skills/reference/decision-guides) |

### BIOS Profiles

Pre-built BIOS configurations in `profiles/`:

- **Virtualization Host** — KVM, Proxmox, ESXi (VT-x, VT-d, SR-IOV, ACS enabled)
- **Database Server** — PostgreSQL, MySQL (HT disabled, NUMA-aware, power performance)
- **HPC / Compute** — AI/ML, scientific computing (max turbo, GPU support, large BAR)
- **Storage Server** — Ceph, ZFS, MinIO (HBA passthrough, I/O optimized)

## Using with an AI Agent

Point your agent (Claude Code, etc.) at this directory. The agent reads `CLAUDE.md` for identity, safety rules, and skill routing, then navigates to the relevant skill for the operator's task.

```bash
# Open in Claude Code
cd supermicro-hardware
claude
```

The agent can then help with tasks like:
- "Set up BMC on a new X13 server"
- "Create a RAID 6 array with 8 drives using storcli"
- "Update firmware on all servers in the fleet"
- "Why is the chassis LED blinking amber?"
- "Export BIOS config and apply it to 10 other servers"

## Project Structure

```
supermicro-hardware/
├── CLAUDE.md                    # Agent entry point
├── stack.yaml                   # Stack manifest
├── .env.example                 # Credential template
├── container/                   # Dockerfile + docker-compose
├── profiles/                    # BIOS profiles by workload
└── skills/                      # Operational knowledge
    ├── foundation/              # Concepts, tools, architecture
    ├── deploy/                  # Container setup, initial config
    ├── operations/              # BIOS, BMC, RAID, firmware, inventory, Ansible
    ├── diagnose/                # Hardware, connectivity, storage troubleshooting
    └── reference/               # Known issues, compatibility, decision guides
```

## Operator Project Structure

When using this stack to manage your servers, your project should look like:

```
my-server-fleet/
├── .env                         # BMC credentials (gitignored)
├── workspace/
│   ├── configs/                 # BMC/BIOS config exports per server
│   ├── firmware/                # Downloaded firmware bundles
│   ├── playbooks/               # Ansible playbooks
│   └── inventory/               # Hardware inventory exports
├── profiles/                    # BIOS profiles
└── container/                   # Dockerfile + docker-compose
```

## License

MIT
