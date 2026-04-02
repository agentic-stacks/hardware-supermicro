# Architecture: Container-Based Tooling

## Why Containerize Supermicro Tools?

Supermicro's management tools have specific OS and library dependencies. Running them in a container solves three core problems:

1. **OS independence** — ipmitool, SUM, and SMCIPMITool ship as Linux binaries targeting RHEL/Rocky. The container runs Rocky Linux regardless of the operator's host OS (Ubuntu, Debian, macOS via Docker Desktop, Windows via WSL2/Docker Desktop).
2. **Version pinning** — every tool version is locked in the Dockerfile. Two operators on different machines get identical tool behavior.
3. **Reproducibility** — `docker build` produces the same toolkit every time. No "works on my machine" when troubleshooting across a team.

> **SUM and SMCIPMITool note:** These tools require downloading from supermicro.com with a registered account. Place the downloaded archives in `container/` before building. The Dockerfile install scripts skip gracefully if the archives are absent — the container still works with ipmitool, curl/Redfish, storcli, and Ansible.

## Container Modes

### Privileged Mode (Local Hardware Access)

```bash
docker compose -f container/docker-compose.yaml up -d smc-tools
```

Uses:
- `privileged: true` — access to host kernel modules and devices
- `network_mode: host` — shares host network stack
- `/dev:/dev` and `/sys:/sys:ro` — read host hardware directly

**When to use:** managing the server the container is running on. Required for:
- `dmidecode` (reads SMBIOS from `/dev/mem`)
- `lshw` (reads `/sys` and `/dev`)
- `ipmitool -I open` local mode (needs `/dev/ipmi0`)
- `storcli64` local mode (needs `/dev/megaraid_sas_ioctl_node`)

**IPMI driver note:** The container entrypoint automatically attempts to load `ipmi_devintf` and `ipmi_si` kernel modules on startup. If successful, `/dev/ipmi0` becomes available and `ipmitool -I open` works. Without the modules, local IPMI mode is unavailable but remote mode (`-I lanplus`) still works.

**Security note:** Privileged containers have full host access. Only use on the server being managed, not on a management workstation.

### Remote-Only Mode

```bash
docker compose -f container/docker-compose.yaml --profile remote up -d smc-tools-remote
```

Uses:
- No privileged mode
- No device passthrough
- Standard container networking

**When to use:** managing remote servers over the network. Sufficient for:
- `ipmitool -I lanplus -H $BMC_HOST` (IPMI over LAN)
- `curl` Redfish API calls
- `sum -i $BMC_HOST` (SUM remote mode)
- `SMCIPMITool $BMC_HOST` (remote mode)
- Ansible playbooks targeting remote BMC interfaces

**Security note:** This is the safer option. Use this mode on a management workstation or jump host.

## Network Flow

```
Operator Workstation                Container                    Target Server
┌─────────────────┐    docker exec   ┌──────────────┐   HTTPS/443   ┌──────────┐
│                 │ ──────────────── │  smc-tools   │ ────────────── │   BMC    │
│  Terminal/Agent │                  │              │   IPMI/623     │          │
│                 │                  │  ipmitool    │ ────────────── │  (ATEN)  │
│                 │                  │  curl/jq     │   SSH/22       │          │
│                 │                  │  sum         │ ────────────── │          │
│                 │                  │  ansible     │                └──────────┘
└─────────────────┘                  └──────────────┘
                                           │
                                     /workspace (mounted)
                                           │
                                    ┌──────────────┐
                                    │ configs/     │
                                    │ firmware/    │
                                    │ playbooks/   │
                                    │ inventory/   │
                                    └──────────────┘
```

## Bare-Metal Installation Alternative

Operators who prefer not to use Docker can install the management tools directly on a Linux management host.

### RHEL / Rocky Linux / CentOS

```bash
# Core tools
dnf install -y ipmitool curl jq dmidecode lshw pciutils

# Ansible + community.general (includes Redfish modules)
pip install ansible
ansible-galaxy collection install community.general

# storcli (download RPM from Broadcom support portal first)
rpm -ivh storcli_<version>_all.rpm
# storcli64 is installed to /opt/MegaRAID/storcli/storcli64
cp /opt/MegaRAID/storcli/storcli64 /usr/local/bin/

# SUM (download tar.gz from supermicro.com — requires account)
tar xzf sum_<version>_Linux_x86_64.tar.gz
cp sum_<version>_Linux_x86_64/sum /usr/local/bin/
chmod +x /usr/local/bin/sum

# SMCIPMITool (download tar.gz from supermicro.com — requires account)
tar xzf SMCIPMITool_<version>_Linux_x86_64.tar.gz
cp SMCIPMITool /usr/local/bin/
chmod +x /usr/local/bin/SMCIPMITool
```

### Debian / Ubuntu

```bash
# Core tools
apt-get install -y ipmitool curl jq dmidecode lshw pciutils

# Ansible + community.general
pip install ansible
ansible-galaxy collection install community.general

# storcli (download RPM from Broadcom, convert with alien, or install DEB if available)
apt-get install -y alien
alien -i storcli_<version>_all.rpm
# Or use the DEB package if Broadcom provides one for your distribution
```

> **SUM and SMCIPMITool:** These tools have no package manager distribution. Always download from supermicro.com and install manually to `/usr/local/bin/`.

## Credential Handling

Credentials never go in committed files. Three approaches, from simplest to most secure:

### 1. Environment File (.env)

The `.env` file at the project root is loaded by docker-compose automatically:

```bash
# .env (gitignored)
BMC_HOST=192.168.1.100
BMC_USER=ADMIN
BMC_PASS=changeme
```

The container receives these as environment variables. Commands inside the container use them:

```bash
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power status
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/Systems/1 | jq '.PowerState'
sum -i $BMC_HOST -u $BMC_USER -p $BMC_PASS -c GetBiosInfo
```

### 2. Ansible Vault (Fleet Operations)

For managing multiple servers with different credentials, store per-server credentials in an Ansible vault:

```bash
ansible-vault create workspace/playbooks/vault.yaml
```

Reference in playbooks with `--ask-vault-pass` or a vault password file:

```bash
ansible-playbook -i inventory.ini playbook.yaml --vault-password-file .vault-pass
```

### 3. Environment Variables (CI/CD)

In automated pipelines, inject credentials at runtime:

```bash
docker exec -e BMC_HOST=10.0.0.1 -e BMC_USER=ADMIN -e BMC_PASS=secret smc-tools \
  ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power status
```

## Volume Mounts

The `/workspace` directory inside the container maps to `workspace/` in the operator's project:

| Container Path | Host Path | Purpose |
|---|---|---|
| `/workspace/configs/` | `workspace/configs/` | BMC/BIOS config exports (SUM XML, Redfish JSON) |
| `/workspace/firmware/` | `workspace/firmware/` | Downloaded firmware archives (BMC, BIOS, RAID) |
| `/workspace/playbooks/` | `workspace/playbooks/` | Ansible playbooks for fleet automation |
| `/workspace/inventory/` | `workspace/inventory/` | Hardware inventory exports (JSON, CSV) |

Files created inside the container appear on the host and vice versa. This enables a GitOps workflow: export BIOS configs inside the container, commit them from the host.

## Container Lifecycle

```bash
# Build the container image
docker compose -f container/docker-compose.yaml build

# Build with Rocky Linux 10
docker compose -f container/docker-compose.yaml build --build-arg ROCKY_VERSION=10

# Start in privileged mode (local hardware access)
docker compose -f container/docker-compose.yaml up -d smc-tools

# Start in remote-only mode
docker compose -f container/docker-compose.yaml --profile remote up -d smc-tools-remote

# Execute a one-off command
docker exec smc-tools ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power status

# Execute with overridden env vars
docker exec -e BMC_HOST=10.0.0.2 smc-tools ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS mc info

# Interactive shell (for exploration and troubleshooting)
docker exec -it smc-tools bash

# Stop and remove container
docker compose -f container/docker-compose.yaml down

# Rebuild after Dockerfile or tool archive changes (no cache)
docker compose -f container/docker-compose.yaml build --no-cache
```
