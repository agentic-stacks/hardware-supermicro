#!/bin/bash
set -e

# Start IPMI driver if available (needed for local ipmitool access)
if [ -c /dev/ipmi0 ] || [ -c /dev/ipmi/0 ] || [ -c /dev/ipmidev/0 ]; then
    echo "IPMI device detected, local ipmitool access available."
elif [ -d /sys/module ]; then
    # Try to load IPMI kernel modules for local access
    modprobe ipmi_devintf 2>/dev/null || true
    modprobe ipmi_si 2>/dev/null || true
    if [ -c /dev/ipmi0 ]; then
        echo "IPMI modules loaded, local access available."
    else
        echo "No IPMI device found. Remote-only mode (ipmitool -I lanplus, Redfish API)."
    fi
else
    echo "Running in remote-only mode (no /sys/module). Use ipmitool -I lanplus or Redfish API."
fi

# Execute the provided command or drop into bash
exec "$@"
