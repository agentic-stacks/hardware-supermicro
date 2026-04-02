#!/bin/bash
# Install storcli if the archive is present in /tmp or the build context
# Operators must download storcli from Broadcom support portal
# and place the Linux RPM or archive in the container/ directory

STORCLI_RPM=$(find /tmp/vendor -name 'storcli*.rpm' 2>/dev/null | head -1)
if [ -n "$STORCLI_RPM" ]; then
    rpm -ivh "$STORCLI_RPM"
    # storcli64 is typically installed to /opt/MegaRAID/storcli/
    if [ -f /opt/MegaRAID/storcli/storcli64 ]; then
        cp /opt/MegaRAID/storcli/storcli64 /usr/local/bin/
    fi
    echo "storcli installed successfully."
else
    echo "No storcli RPM found. storcli will not be available."
    echo "Download from Broadcom support portal and place in container/ directory."
fi
