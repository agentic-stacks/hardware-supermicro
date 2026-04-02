# Compatibility Matrices

Quick-reference tables for which tools and Redfish features are supported on each Supermicro platform generation.

## Platform vs Tool Support

| Tool | X11 | X12 | X13 | Notes |
|---|---|---|---|---|
| ipmitool | Full | Full | Full | IPMI 2.0 supported on all platforms |
| Redfish API | Partial | Full | Full | X11 has limited Redfish; X12/X13 have full support |
| SUM | Full | Full | Full | Download the per-platform version from supermicro.com |
| SMCIPMITool | Full | Full | Full | Works across all platforms |
| storcli | Full | Full | Full | Depends on controller model, not platform generation |
| IPMIView | Full | Full | Full | Java-based GUI; works across all platforms |

## Redfish Feature Support by Platform

| Feature | X11 | X12 | X13 |
|---|---|---|---|
| Basic system info | Yes | Yes | Yes |
| BIOS attribute read/write | Limited | Yes | Yes |
| Firmware update (SimpleUpdate) | No | Yes | Yes |
| Virtual media | No | Yes | Yes |
| Event subscriptions | No | Partial | Yes |
| Telemetry | No | No | Partial |

> **X11 Redfish note:** X11 boards have early Redfish implementations. For X11, prefer ipmitool and SUM over Redfish for reliable scripting.

## Ansible Module Compatibility

| Module | Minimum Redfish | Works With |
|---|---|---|
| `redfish_info` | Any | X11, X12, X13 |
| `redfish_command` | 1.6+ | X12, X13 |
| `redfish_config` (BIOS) | 1.6+ | X12, X13 |
| `ipmi_power` | Any (IPMI 2.0) | X11, X12, X13 |
