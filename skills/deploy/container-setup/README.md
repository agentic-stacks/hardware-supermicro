# Container Setup

## Purpose

Build and start the Supermicro tools container that provides ipmitool, curl, jq, Ansible, and optional Supermicro vendor tools (SUM, SMCIPMITool, storcli) in a single environment.

## Prerequisites

| Requirement | Check Command | Expected Output |
|---|---|---|
| Docker Engine | `docker --version` | Docker version 24.x or later |
| Docker Compose v2 | `docker compose version` | Docker Compose version v2.x or later |
| Network access to BMC | `ping -c 3 $BMC_HOST` | 0% packet loss |
| Repository cloned | `ls container/docker-compose.yaml` | File exists |

## Quick Start

### Step 1: Create the Environment File

Copy the example environment file and edit it with your site-specific values:

```bash
cp .env.example .env
```

Edit `.env` and set at minimum:

| Variable | Example Value | Description |
|---|---|---|
| `BMC_HOST` | `192.168.1.100` | BMC IP address or hostname |
| `BMC_USER` | `ADMIN` | BMC username |
| `BMC_PASS` | `ADMIN` | BMC password |

### Step 2: Build the Container Image

```bash
docker compose -f container/docker-compose.yaml build
```

This installs all open-source management tools into a Rocky Linux base image. Build time is approximately 3-5 minutes depending on network speed. Vendor tools (SUM, SMCIPMITool, storcli) are only included if their archives are present in the `container/` directory — see [Adding Vendor Tools](#adding-vendor-tools) below.

### Step 3: Start the Container

Choose the profile that matches your deployment scenario.

#### Option A: Local Management (Privileged)

Use this when the management host is the Supermicro server itself or has direct IPMI device access. The container runs in privileged mode to access local hardware devices (`/dev/ipmi0`).

> **Privileged mode is required** for local hardware access. Without it, local ipmitool commands that target the in-band IPMI device will fail with "Could not open device".

```bash
docker compose -f container/docker-compose.yaml up -d smc-tools
```

#### Option B: Remote-Only Management

Use this when managing the server exclusively over the network via IPMI LAN+. No privileged access is required.

```bash
docker compose -f container/docker-compose.yaml --profile remote up -d smc-tools-remote
```

#### Decision Tree: Which Profile?

```
Are you running on the Supermicro server itself (or need /dev/ipmi0 access)?
  YES --> Option A: Local Management (privileged)
  NO  --> Are you managing only via IPMI LAN+ over the network?
            YES --> Option B: Remote-Only
            NO  --> Option A: Local Management (privileged)
```

## Adding Vendor Tools

Supermicro vendor tools (SUM, SMCIPMITool) and the Broadcom storcli utility require manual download before building the container. They are not fetched automatically because they require a Supermicro customer portal login or Broadcom download agreement.

### SUM (Supermicro Update Manager)

1. Download from [Supermicro Downloads](https://www.supermicro.com/en/support/resources/downloadcenter/firmware)
2. Locate the SUM Linux x86_64 archive (e.g., `sum_2.x.x_Linux_x86_64_static.tar.gz`)
3. Place the archive in the `container/` directory
4. Rebuild the container:

```bash
docker compose -f container/docker-compose.yaml build --no-cache
docker compose -f container/docker-compose.yaml up -d smc-tools
```

### SMCIPMITool

1. Download from [Supermicro Downloads](https://www.supermicro.com/en/support/resources/downloadcenter/firmware)
2. Locate the SMCIPMITool Linux archive (e.g., `SMCIPMITool_2.x.x_build_Linux_x86_64.tar.gz`)
3. Place the archive in the `container/` directory
4. Rebuild the container:

```bash
docker compose -f container/docker-compose.yaml build --no-cache
docker compose -f container/docker-compose.yaml up -d smc-tools
```

### storcli (Broadcom RAID CLI)

1. Download from [Broadcom Support](https://www.broadcom.com/support/download-search?pg=Storage+Adapters,+Controllers,+and+ICs&pf=RAID+Controller+Cards&pn=)
2. Locate the storcli Linux RPM (e.g., `storcli-7.x-1.noarch.rpm`)
3. Place the RPM in the `container/` directory
4. Rebuild the container:

```bash
docker compose -f container/docker-compose.yaml build --no-cache
docker compose -f container/docker-compose.yaml up -d smc-tools
```

## Verification

Run each command to verify the container and tool availability. Core tools must succeed; vendor tool checks will print a "not installed" message if the archive was not present at build time.

### Verify Core Tools

```bash
# ipmitool (IPMI management)
docker exec smc-tools ipmitool -V

# curl and jq (Redfish API access)
docker exec smc-tools curl --version
docker exec smc-tools jq --version

# Ansible (automation)
docker exec smc-tools ansible --version
```

### Verify Vendor Tools (if installed)

```bash
docker exec smc-tools sum --version 2>/dev/null || echo "SUM not installed"
docker exec smc-tools SMCIPMITool 2>/dev/null | head -1 || echo "SMCIPMITool not installed"
docker exec smc-tools storcli64 show 2>/dev/null || echo "storcli not installed"
```

### Test BMC Connectivity

```bash
# IPMI LAN+ power status
docker exec smc-tools ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power status

# Redfish system info
docker exec smc-tools curl -sk -u $BMC_USER:$BMC_PASS \
  https://$BMC_HOST/redfish/v1/Systems/1 | jq '.PowerState'
```

### Verification Decision Tree

```
Did all core tool checks succeed?
  YES --> Did BMC connectivity tests succeed?
            YES --> Container setup is complete. Proceed to initial-config.
            NO  --> See Troubleshooting: IPMI or Redfish connection refused
  NO  --> Which command failed?
            ipmitool   --> See Troubleshooting: Missing ipmitool
            curl / jq  --> See Troubleshooting: Container not running
            ansible    --> See Troubleshooting: Container not running
            all        --> See Troubleshooting: Container not running
```

## Interactive Shell

To open an interactive shell inside the container for ad-hoc commands:

```bash
docker exec -it smc-tools bash
```

Exit with `exit` or Ctrl-D. The container continues running after you exit.

## Rebuilding After Updates

When the Dockerfile or tool versions are updated, rebuild and restart:

```bash
docker compose -f container/docker-compose.yaml build --no-cache
docker compose -f container/docker-compose.yaml down
docker compose -f container/docker-compose.yaml up -d smc-tools
```

For remote-only deployments:

```bash
docker compose -f container/docker-compose.yaml build --no-cache
docker compose -f container/docker-compose.yaml --profile remote down
docker compose -f container/docker-compose.yaml --profile remote up -d smc-tools-remote
```

## Bare-Metal Alternative

If you prefer to install tools directly on the management host instead of using the container, use the commands below.

### RHEL / Rocky Linux / AlmaLinux

```bash
# Core tools
sudo dnf install -y ipmitool curl jq python3-pip

# Ansible
pip3 install --user ansible

# Install SUM (after downloading the archive)
tar -xzf sum_2.x.x_Linux_x86_64_static.tar.gz
sudo cp sum /usr/local/bin/sum
sudo chmod +x /usr/local/bin/sum

# Install SMCIPMITool (after downloading the archive)
tar -xzf SMCIPMITool_2.x.x_build_Linux_x86_64.tar.gz
sudo cp SMCIPMITool /usr/local/bin/SMCIPMITool
sudo chmod +x /usr/local/bin/SMCIPMITool

# Install storcli (after downloading the RPM)
sudo rpm -ivh storcli-7.x-1.noarch.rpm
```

### Debian / Ubuntu

```bash
# Core tools
sudo apt-get update
sudo apt-get install -y ipmitool curl jq python3-pip

# Ansible
pip3 install --user ansible

# Install SUM (after downloading the archive)
tar -xzf sum_2.x.x_Linux_x86_64_static.tar.gz
sudo cp sum /usr/local/bin/sum
sudo chmod +x /usr/local/bin/sum

# Install SMCIPMITool (after downloading the archive)
tar -xzf SMCIPMITool_2.x.x_build_Linux_x86_64.tar.gz
sudo cp SMCIPMITool /usr/local/bin/SMCIPMITool
sudo chmod +x /usr/local/bin/SMCIPMITool

# Install storcli (convert RPM to DEB, or extract manually)
sudo apt-get install -y alien
sudo alien --to-deb storcli-7.x-1.noarch.rpm
sudo dpkg -i storcli_7.x-2_all.deb
```

When using bare-metal installation, omit the `docker exec smc-tools` prefix from all commands in this guide and run them directly.

## Troubleshooting

### Container Not Running

```bash
# Check container status
docker compose -f container/docker-compose.yaml ps

# Check logs for startup errors
docker compose -f container/docker-compose.yaml logs smc-tools
```

If the container exited immediately, check the logs for missing environment variables or mount path errors.

### IPMI Connection Refused (Port 623)

Symptom: `ipmitool` returns "Connection refused" or times out.

| Cause | Fix |
|---|---|
| BMC not yet reachable on the network | Verify the BMC IP is correct; try `ping $BMC_HOST` |
| Firewall blocking UDP 623 | Open UDP port 623 from the management host to the BMC IP |
| BMC IPMI-over-LAN not enabled | Enable via the BMC web UI under Network → IPMI Settings |
| Wrong credentials | Supermicro default is ADMIN / ADMIN (both uppercase) |

### Redfish Connection Refused (Port 443)

Symptom: `curl` returns "Connection refused" or SSL error.

```bash
# Test basic HTTPS connectivity
curl -sk https://$BMC_HOST/redfish/v1/ | jq '.RedfishVersion'
```

| Cause | Fix |
|---|---|
| Self-signed TLS certificate | Always use `-sk` (skip cert verification) for BMC Redfish calls |
| HTTPS not enabled on BMC | Enable via BMC web UI under Network → Web Settings |
| Firewall blocking TCP 443 | Open TCP port 443 from the management host to the BMC IP |
| Wrong BMC IP | Verify with `ipmitool lan print 1` from the local host |

### DNS Resolution Failures Inside Container

Symptom: commands inside the container cannot resolve hostnames.

```bash
docker exec smc-tools nslookup pool.ntp.org
```

Fix: add DNS servers to `container/docker-compose.yaml` under the service definition:

```yaml
    dns:
      - 8.8.8.8
      - 8.8.4.4
```

Restart the container after editing.

### Privilege Errors (Local Management)

Symptom: "Could not open device at /dev/ipmi0" or "Permission denied".

Verify the container is running in privileged mode:

```bash
docker inspect smc-tools --format '{{.HostConfig.Privileged}}'
```

Expected: `true`. If `false`, you started the remote-only profile. Stop it and start with Option A instead.

### Missing Tools After Build

If a specific tool binary is missing after the build, rebuild without the cache to pull fresh packages:

```bash
docker compose -f container/docker-compose.yaml build --no-cache
```

Then restart the container.
