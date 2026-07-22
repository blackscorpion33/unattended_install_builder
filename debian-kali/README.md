# Unattended ISO Builders

Automated hybrid ISO generator for unattended Debian and Kali Linux installations, using WSL.

## Features

* **Debian & Kali Support** 
  Build unattended installers for either distro using the same script.
* **Automated or Interactive Disk Selection**  
  Choose full auto-wipe automation or prompt for disk selection during install.
* **Optional Post-Install Module Sync**  
  Automatically copy your `/home/docker/core-modules` directory into the installed OS.
* **Boot Menu Bypass**  
  Skip GRUB/ISOLINUX boot menus and launch the installer immediately.
* **Dynamic Preseed Generation**  
  `preseed.cfg` is generated on-the-fly based on flags and distro selection.
* **Clean ISO Rebuild Pipeline**  
  Extract → Modify → Inject → Repack → Output.

---

## Usage Flags

| Flag | Description |
| --- | --- |
| `-d, --distro <debian\|kali>` | Select target distro (Default: `debian`) |
| `-g, --desktop <xfce\|gnome\|kde\|cinnamon\|mate>` | Select desktop environment for Debin or Kali (Default: `xfce`) |
| `-i, --interactive` | Prompt for disk selection instead of auto-wipe |
| `-p, --postinstall` | Sync `/home/docker/core-modules` into the target OS |
| `-b, --bypass-menu` | Skip boot menu timeout and auto-start installer |
| `-h, --help` | Show help menu |

---

## Example Usage

```bash
# Running with no flags defaults to Debian 100% unattended
sudo ./universal_iso_maker.sh

# Debian with interactive disk selection
sudo ./universal_iso_maker.sh --distro debian --interactive

# Kali Linux with boot menu bypass
sudo ./universal_iso_maker.sh --distro kali --bypass-menu
```

## Technical Details:

## Post-Install Sync (--postinstall)

If enabled, the script copies your local /home/docker/core-modules directory into the ISO staging environment and injects it into the target OS via late_command.


## This allows you to preload:

Automation scripts

System configs

Dotfiles

Provisioning modules

Service installers


## Boot Menu Bypass (--bypass-menu)

If enabled, the script modifies the installer's bootloaders:

Sets ISOLINUX timeout to 0 and forces default to install

Sets GRUB timeout to 0 and forces default entry

Enables immediate autoboot

This makes the ISO completely hands-free — ideal for hypervisor auto-rebuilds.

## Preseed Injection

The pipeline performs the following steps:

Extracts the source ISO using xorriso.

Unpacks install.amd/initrd.gz.

Injects a dynamically rendered preseed.cfg.

Repacks initrd.gz and recalculates ISO md5sum.txt hashes.

Compiles a hybrid EFI/BIOS bootable ISO.

## Notes & Prerequisites

Sensitive Data: Preseed passwords and usernames in the script are placeholders. Update them before running.

Core Modules Directory: /home/docker/core-modules is not included in the repository. You must create it locally if using --postinstall.

License
MIT License — Free to use, modify, and extend.
