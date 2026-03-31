#!/bin/bash
# Install SUM (Supermicro Update Manager) if the archive is provided
# Operators must download SUM from supermicro.com (requires account)

SUM_ARCHIVE=$(find /tmp/vendor -name 'sum_*_Linux_x86_64*.tar.gz' -o -name 'SUM*.tar.gz' 2>/dev/null | head -1)
if [ -n "$SUM_ARCHIVE" ]; then
    cd /tmp
    tar xzf "$SUM_ARCHIVE"
    SUM_DIR=$(find /tmp/vendor -maxdepth 1 -type d -name 'sum*' -o -name 'SUM*' 2>/dev/null | head -1)
    if [ -n "$SUM_DIR" ] && [ -f "$SUM_DIR/sum" ]; then
        cp "$SUM_DIR/sum" /usr/local/bin/
        chmod +x /usr/local/bin/sum
        echo "SUM installed successfully."
    else
        echo "SUM archive found but could not locate sum binary."
    fi
    rm -rf "$SUM_ARCHIVE" "$SUM_DIR"
else
    echo "No SUM archive found. SUM will not be available."
    echo "Download from supermicro.com and place in container/ directory."
fi
