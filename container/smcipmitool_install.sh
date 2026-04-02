#!/bin/bash
# Install SMCIPMITool if the archive is provided
# Operators must download from supermicro.com (requires account)

SMCI_ARCHIVE=$(find /tmp/vendor -name 'SMCIPMITool*Linux*.tar.gz' 2>/dev/null | head -1)
if [ -n "$SMCI_ARCHIVE" ]; then
    cd /tmp
    tar xzf "$SMCI_ARCHIVE"
    SMCI_BIN=$(find /tmp/vendor -name 'SMCIPMITool' -type f 2>/dev/null | head -1)
    if [ -n "$SMCI_BIN" ]; then
        cp "$SMCI_BIN" /usr/local/bin/
        chmod +x /usr/local/bin/SMCIPMITool
        echo "SMCIPMITool installed successfully."
    else
        echo "SMCIPMITool archive found but could not locate binary."
    fi
    rm -rf "$SMCI_ARCHIVE"
else
    echo "No SMCIPMITool archive found. SMCIPMITool will not be available."
    echo "Download from supermicro.com and place in container/ directory."
fi
