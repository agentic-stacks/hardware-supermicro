# Ansible — Fleet Automation

## Overview

Unlike Dell which has a dedicated `dellemc.openmanage` collection, Supermicro fleet automation uses standard community modules:

| Module | Purpose |
|---|---|
| `community.general.redfish_info` | Gather Redfish data (inventory, status) |
| `community.general.redfish_command` | Execute Redfish actions (power, firmware update) |
| `community.general.redfish_config` | Configure Redfish resources (BIOS attributes) |
| `community.general.ipmi_power` | IPMI power management |
| `community.general.ipmi_boot` | IPMI boot device control |

## When to Use Ansible vs Direct Commands

| Scenario | Tool |
|---|---|
| Single server, one-off command | ipmitool / curl (Redfish) |
| Multiple servers, same operation | Ansible |
| Config-as-code BIOS profiles | Ansible |
| Automated / scheduled operations | Ansible |
| Interactive troubleshooting | ipmitool / curl (Redfish) |

## Installation

```bash
pip install ansible
ansible-galaxy collection install community.general
```

## Inventory File

```ini
# workspace/playbooks/inventory.ini
[bmc_hosts]
server01-bmc ansible_host=10.0.10.101
server02-bmc ansible_host=10.0.10.102
server03-bmc ansible_host=10.0.10.103

[bmc_hosts:vars]
ansible_connection=local
ansible_python_interpreter=/usr/bin/python3
bmc_user=ADMIN
bmc_password="{{ vault_bmc_password }}"
```

## Example Playbook: Gather Inventory

```yaml
# workspace/playbooks/gather-inventory.yaml
---
- name: Gather Supermicro server inventory
  hosts: bmc_hosts
  gather_facts: false
  vars:
    bmc_user: "{{ vault_bmc_user }}"
    bmc_password: "{{ vault_bmc_password }}"

  tasks:
    - name: Get system info via Redfish
      community.general.redfish_info:
        baseuri: "{{ ansible_host }}"
        username: "{{ bmc_user }}"
        password: "{{ bmc_password }}"
        category: Systems
        command: GetSystemInventory
      register: system_info

    - name: Save inventory to file
      copy:
        content: "{{ system_info | to_nice_json }}"
        dest: "workspace/inventory/{{ inventory_hostname }}-inventory.json"
      delegate_to: localhost
```

## Example Playbook: Configure BIOS

```yaml
# workspace/playbooks/set-bios.yaml
---
- name: Apply BIOS settings to Supermicro fleet
  hosts: bmc_hosts
  gather_facts: false

  tasks:
    - name: Set BIOS attributes for virtualization
      community.general.redfish_config:
        baseuri: "{{ ansible_host }}"
        username: "{{ bmc_user }}"
        password: "{{ bmc_password }}"
        category: Systems
        command: SetBiosAttributes
        bios_attributes:
          HyperThreading: "Enabled"
          VMX: "Enabled"
          VTd: "Enabled"
          SR-IOV: "Enabled"

    - name: Reboot to apply BIOS changes
      community.general.redfish_command:
        baseuri: "{{ ansible_host }}"
        username: "{{ bmc_user }}"
        password: "{{ bmc_password }}"
        category: Systems
        command: PowerGracefulRestart
```

## Example Playbook: Power Management

```yaml
# workspace/playbooks/power-control.yaml
---
- name: Power control for Supermicro fleet
  hosts: bmc_hosts
  gather_facts: false

  tasks:
    - name: Graceful shutdown
      community.general.ipmi_power:
        name: "{{ ansible_host }}"
        user: "{{ bmc_user }}"
        password: "{{ bmc_password }}"
        state: shutdown
```

## Example Playbook: Firmware Update

```yaml
# workspace/playbooks/update-firmware.yaml
---
- name: Update BMC firmware on Supermicro fleet
  hosts: bmc_hosts
  gather_facts: false
  serial: 1  # Update one server at a time

  tasks:
    - name: Update BMC firmware via Redfish
      community.general.redfish_command:
        baseuri: "{{ ansible_host }}"
        username: "{{ bmc_user }}"
        password: "{{ bmc_password }}"
        category: Update
        command: SimpleUpdate
        update_image_uri: "http://firmware-repo.internal/supermicro/BMC_latest.bin"
      register: update_result

    - name: Wait for BMC to restart
      wait_for:
        host: "{{ ansible_host }}"
        port: 443
        delay: 60
        timeout: 300
      delegate_to: localhost
```

## Credential Management

```bash
# Create encrypted vault file
ansible-vault create workspace/playbooks/vault.yaml
# Add:
#   vault_bmc_user: ADMIN
#   vault_bmc_password: YourSecurePassword

# Run a playbook with vault decryption
ansible-playbook -i workspace/playbooks/inventory.ini \
  workspace/playbooks/gather-inventory.yaml --ask-vault-pass

# Run against a single server
ansible-playbook -i workspace/playbooks/inventory.ini \
  workspace/playbooks/gather-inventory.yaml \
  --limit server01-bmc --ask-vault-pass

# Dry run (check mode — no changes applied)
ansible-playbook -i workspace/playbooks/inventory.ini \
  workspace/playbooks/set-bios.yaml --check --ask-vault-pass
```
