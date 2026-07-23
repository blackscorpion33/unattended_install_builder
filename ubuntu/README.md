# Ubuntu Server Autoinstall ISO Builder

A lightweight Bash script pipeline to generate unattended, fully automated **Ubuntu Server** ISOs. It embeds custom cloud-init (`autoinstall.yaml`) definitions, prepends an automated boot entry to GRUB, and auto-cleans working directories upon completion.

---

## 🛠️ Features

* **Fully Automated Boot:** Pre-configures GRUB with a 2-second timeout and auto-executes the installer without user intervention.
* **Declarative Package Baking:** Pre-installs required server packages (`wireguard`, `fail2ban`, `btop`, `docker` prerequisites, etc.) directly during OS creation.
* **Gitea Integration:** Pulls post-install modules (`core-modules`) dynamically from your self-hosted Gitea instance via `late-commands`.
* **Clean Workspace Trap:** Uses a Bash `EXIT` trap to guarantee temporary extraction directories (`iso-work`) are cleaned up even on script failure or `Ctrl+C`.
* **Don't forget to adjust the static ip to your neeeds

---

## 📁 Prerequisites

Ensure you have `xorriso` installed on your host system:

```bash
sudo apt update && sudo apt install -y xorriso
```

### File Layout

Place your source ISO and target `autoinstall.yaml` in your working directory path (adjust variables in script if needed):

```text
/mnt/e/iso/ubuntu/
├── ubuntu-26.04-live-server-amd64.iso  # Source ISO
├── autoinstall.yaml                    # Your cloud-config rules
└── build-iso.sh                        # This builder script
```

---

## 🚀 Usage

1. Make the script executable:
   ```bash
   chmod +x build-iso.sh
   ```

2. Run the script:
   ```bash
   sudo ./build-iso.sh
   ```

3. Your output ISO will be saved to:
   ```text
   /mnt/e/iso/ubuntu/complete/ubuntu-server-autoinstall.iso
   ```

---

## ⚙️ Configuration Snippets

### `autoinstall.yaml` Structure

The script injects your local `autoinstall.yaml` into `/nocloud/user-data` inside the ISO. Ensure your config includes the Gitea clone hook under `late-commands`:

```yaml
#cloud-config
autoinstall:
  version: 1

  # Native package installation during build phase
  packages:
    - wireguard
    - curl
    - git
    - btop
    - net-tools

  # Late commands to clone core scripts into target OS
  late-commands:
    - curtin in-target -- mkdir -p /home/docker
    - curtin in-target -- git clone https://<TOKEN>@gitea.yourdomain.com/youruser/core-modules.git /home/docker/core-modules
    - curtin in-target -- chmod +x /home/docker/core-modules/postinstall/postinstall.sh
```

---

## 🔍 How It Works

1. **Extraction:** Uses `xorriso` to unpack the source ISO into `iso-work/`.
2. **Config Injection:** Normalizes `#cloud-config` headers and places `user-data` into both `/nocloud` and `/autoinstall` directories on the ISO.
3. **GRUB Modification:** Prepends an `Automated Unattended Installation` entry to `/boot/grub/grub.cfg` with `autoinstall ds=nocloud`.
4. **Repackaging:** Uses `xorriso` raw interval mapping to reconstruct a bootable hybrid ISO compatible with both UEFI and legacy BIOS.
5. **Cleanup:** Automatically purges `iso-work/` upon completion.
