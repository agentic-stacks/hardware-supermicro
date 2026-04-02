# Foundation Skills: Supermicro Hardware Management

## Purpose

Establish baseline knowledge for managing Supermicro servers programmatically. Complete this phase before attempting firmware updates, RAID configuration, or fleet-wide automation.

## Sub-Skills

| Sub-Skill | Path | What It Covers |
|---|---|---|
| Concepts | `concepts/` | Supermicro X11/X12/X13 platforms, BMC architecture, firmware hierarchy, Redfish API |
| Tools | `tools/` | ipmitool, Redfish API (curl + jq), SUM, SMCIPMITool, storcli, local discovery utilities |
| Architecture | `architecture/` | Container-based tooling, privileged vs remote modes, bare-metal installation, security |

## Routing

Use this decision tree to determine which sub-skill to consult:

1. **Need to understand what a platform is or how Supermicro systems are organized?** Read `concepts/README.md`.
2. **Need to choose a CLI tool or understand command syntax?** Read `tools/README.md`.
3. **Need to set up the containerized environment or understand runtime configuration?** Read `architecture/README.md`.

## Prerequisites

- Familiarity with Linux system administration
- Docker and docker-compose installed on the management host (optional — see `architecture/README.md` for bare-metal alternative)
- Network access to target BMC interfaces (port 443 for HTTPS/Redfish, port 623 for IPMI)
- BMC credentials for target servers

## Completion Criteria

After completing the foundation phase, the agent should be able to:

- Identify a Supermicro server platform (X11/X12/X13) and understand its BMC capabilities
- Explain the role of the BMC and how it differs from Dell's iDRAC
- Select the correct CLI tool for a given management task (ipmitool vs Redfish vs SUM vs storcli)
- Launch the Supermicro tools container in the appropriate mode (privileged or remote), or install tools bare-metal
- Authenticate to a BMC and retrieve basic system inventory via ipmitool or Redfish
