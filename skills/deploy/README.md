# Deploy Phase

## Purpose

Get from zero to a working management environment: set up the Supermicro tools container (if needed) and perform initial BMC configuration on a new or unconfigured server.

## Sub-Skills

| Sub-Skill | Path | Use When |
|---|---|---|
| Container Setup | `container-setup/README.md` | You need to build, start, or troubleshoot the Supermicro tools container |
| Initial Config | `initial-config/README.md` | You need to configure BMC networking, credentials, NTP, DNS, SNMP, or export a baseline config |

## Decision Tree

```
Do you need a containerised tooling environment?
  YES --> Follow container-setup/README.md first
  NO  --> Skip to initial-config (tools already available on host)

Is the BMC reachable and configured?
  NO  --> Follow initial-config/README.md
  YES --> Deploy phase is complete. Proceed to the next phase.
```

## Quick Verification

Run these commands to confirm the deploy phase is complete:

```bash
# BMC is reachable and responding
ipmitool -I lanplus -H $BMC_HOST -U $BMC_USER -P $BMC_PASS power status

# Redfish API is available
curl -sk -u $BMC_USER:$BMC_PASS https://$BMC_HOST/redfish/v1/ | jq '.RedfishVersion'

# Baseline configs saved
ls -la workspace/configs/
```

## Prerequisites

- Docker and docker-compose installed on the management host (for container path)
  OR ipmitool, curl, and jq installed directly on the host (for bare-metal path)
- Network access to the target server's BMC management port
- BMC credentials (Supermicro default: ADMIN / ADMIN)

## Ordering

Execute sub-skills in this order:

1. **Container Setup** (optional) — provides all Supermicro management tools in a single image
2. **Initial Config** — configure the BMC and export a baseline before any other operations
