# bootstrap

Automated Ubuntu Server installation that calls the existing working [anvil](https://github.com/Beta-Techno/anvil) provisioning process.

## What This Does

```
Bare Metal/VM
    ↓
autoinstall.yaml (Ubuntu Server 24.04 installation)
    ↓
first-boot.sh (runs on first boot)
    ↓
curl anvil/install.sh (your existing working command)
    ↓
Fully Provisioned System
```

## Quick Start

### Option 1: Manual Test (Existing VM)

If you already have Ubuntu installed, test first-boot.sh manually:

```bash
# On your Ubuntu VM:
curl -fsSL https://raw.githubusercontent.com/Beta-Techno/bootstrap/main/scripts/first-boot.sh | sudo bash

# Check the log:
sudo tail -f /var/log/first-boot.log
```

### Option 2: Proxmox Cloud-Init

1. Upload `autoinstall.yaml` to Proxmox snippets:
```bash
# On Proxmox host:
scp autoinstall.yaml root@proxmox:/var/lib/vz/snippets/ubuntu-autoinstall.yaml
```

2. Create VM with cloud-init:
```bash
# On Proxmox host:
qm create 9000 --name bootstrap-test --memory 4096 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9000 ubuntu-24.04-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --cicustom "user=local:snippets/ubuntu-autoinstall.yaml"
qm resize 9000 scsi0 +20G
qm start 9000
```

3. Watch installation:
```bash
qm terminal 9000
```

### Option 3: Custom Ubuntu ISO

Create a custom ISO with autoinstall embedded (advanced).

## Configuration

### Before First Use

**1. Change the default password:**

```bash
# Generate a new password hash:
openssl passwd -6 YourSecurePasswordHere

# Copy the output and replace the password in autoinstall.yaml line 39
```

**2. Add your SSH public key:**

Edit `autoinstall.yaml` line 46-47:
```yaml
authorized-keys:
  - "ssh-ed25519 AAAAC3Nza... your-key-here"
```

**3. Customize settings (optional):**
- Hostname (line 35)
- Timezone (line 64, 106)
- Disk layout (line 27-31)
- Additional packages (line 50-54)

### Environment Variables

Override anvil install behavior via first-boot.sh:

```bash
# In autoinstall.yaml, modify the service or run manually:
ANVIL_INSTALL_URL=https://your-fork.com/anvil/install.sh \
TAGS=base,docker \
ANSIBLE_ARGS='--skip-tags docker_desktop,snap_apps' \
/usr/local/bin/first-boot.sh
```

## Files

```
bootstrap/
├── autoinstall.yaml           # Ubuntu Server installation config
├── scripts/
│   └── first-boot.sh          # Calls existing anvil install
├── docs/
│   └── proxmox-setup.md       # Detailed Proxmox instructions
└── README.md                  # This file
```

## How It Works

### 1. autoinstall.yaml

Ubuntu Server's automated installer config:
- Partitions disk with LVM
- Creates `deploy` user
- Installs base packages (curl, git, ssh)
- Downloads `first-boot.sh` from GitHub
- Creates systemd service to run on first boot
- Reboots

### 2. first-boot.sh

Runs once on first boot:
- Checks network connectivity
- Runs your existing working command:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/Beta-Techno/anvil/main/install.sh | \
    TAGS='all' ANSIBLE_ARGS='--skip-tags docker_desktop' bash
  ```
- Logs everything to `/var/log/first-boot.log`
- Creates `/var/lib/first-boot-complete` marker (won't run again)

### 3. anvil/install.sh

Your existing working ansible provisioning (unchanged).

## Troubleshooting

### Check first-boot status:

```bash
# SSH into the VM:
ssh deploy@<vm-ip>

# Check if first-boot ran:
ls -la /var/lib/first-boot-complete

# Check the log:
sudo tail -100 /var/log/first-boot.log

# Check service status:
sudo systemctl status first-boot.service

# Re-run manually if needed:
sudo rm /var/lib/first-boot-complete
sudo systemctl restart first-boot.service
```

### Common issues:

**"No network connectivity"**
- Wait 30 seconds after boot for network to come up
- Check DHCP is working: `ip addr`

**"curl: command not found"**
- Autoinstall didn't complete properly
- Check Ubuntu installer logs

**Ansible playbook fails**
- Check `/var/log/first-boot.log` for specific error
- SSH in and run anvil manually to debug

## Testing Workflow

1. **Test first-boot.sh manually** on existing VM
2. **Test autoinstall.yaml** in Proxmox
3. **Verify full workflow** from bare metal to provisioned

## Evolution Path

**Now (v1):**
```
autoinstall → first-boot → anvil → done
```

**Later (when mani is added to anvil):**
```
autoinstall → first-boot → anvil → mani sync → done
```

**Future (when flakes is complete):**
```
autoinstall → first-boot → nix → flakes → done
```

Bootstrap remains the same, just the payload changes.

## Security Notes

1. **Change the default password** before production use
2. **Add your SSH key** and disable password auth
3. **Review ansible tags** - don't install unnecessary services
4. **Use HTTPS** for script downloads (already configured)
5. **Verify checksums** for production (TODO: add to first-boot.sh)

## Related Repos

- [anvil](https://github.com/Beta-Techno/anvil) - Ansible provisioning (what this calls)
- [mani](https://github.com/Beta-Techno/mani) - Repo catalog (future: added to anvil)
- [axis](https://github.com/Beta-Techno/axis) - Command plane (future integration)

## License

MIT © Beta Technology
