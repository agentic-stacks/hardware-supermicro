ARG ROCKY_VERSION="9"
FROM rockylinux:${ROCKY_VERSION}

LABEL maintainer="agentic-stacks"
LABEL description="Supermicro server hardware management toolkit — BMC, BIOS, RAID, firmware"

# renovate: datasource=pypi depName=ansible
ARG ANSIBLE_VERSION="10.6.0"

# Supermicro SUM download URL — operators may need to update this from supermicro.com
# SUM requires a Supermicro account to download; place the archive in container/ if building locally
ARG SUM_ARCHIVE=""

# SMCIPMITool download URL — same as above
ARG SMCIPMITOOL_ARCHIVE=""

# Core system packages
RUN \
  dnf update -y && \
  dnf install -y \
    bash \
    curl \
    dmidecode \
    git \
    ipmitool \
    jq \
    kmod \
    lshw \
    net-tools \
    OpenIPMI \
    pciutils \
    python3-pip \
    wget \
    usbutils \
    util-linux \
    unzip && \
  dnf clean all && \
  rm -rf /var/cache/yum

# Ansible + community.general collection (includes Redfish modules)
RUN \
  pip install --no-cache-dir ansible==${ANSIBLE_VERSION} && \
  ansible-galaxy collection install community.general

# Vendor tool installation — optional, tools installed if archives are present.
# Place vendor archives in container/ before building:
#   - storcli RPM from Broadcom support portal
#   - SUM tar.gz from supermicro.com
#   - SMCIPMITool tar.gz from supermicro.com
# We COPY the entire build context to /tmp/vendor/ so install scripts can find them.
# This is safe because the build context is small (scripts + optional archives).
COPY . /tmp/vendor/

# Broadcom storcli for MegaRAID controllers
RUN chmod +x /tmp/vendor/storcli_install.sh && /tmp/vendor/storcli_install.sh

# SUM (Supermicro Update Manager)
RUN chmod +x /tmp/vendor/sum_install.sh && /tmp/vendor/sum_install.sh

# SMCIPMITool
RUN chmod +x /tmp/vendor/smcipmitool_install.sh && /tmp/vendor/smcipmitool_install.sh

# Clean up vendor staging
RUN rm -rf /tmp/vendor/

WORKDIR /workspace

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
