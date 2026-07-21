#!/usr/bin/env bash
# ==============================================================================
# UNIVERSAL UNATTENDED ISO GENERATOR (Debian / Kali)
# ==============================================================================

set -e

# ------------------------------------------------------------------------------
# 1. DEFAULT CONFIGURATION VARIABLES
# ------------------------------------------------------------------------------
DISTRO="debian"                  # Default distro: debian | kali
DEBIAN_DESKTOP=""
KALI_DESKTOP=""                  # Default Kali desktop: empty = headless
INTERACTIVE_DISK="false"         # Default: fully automated disk wiping
POST_INSTALL="false"             # Default: do not include postinstall sync
BYPASS_MENU="false"              # Default: keep normal boot menu timeout

WINDOWS_ISO_DIR="/mnt/c/iso/"

# Credentials & Localization
USER_PASSWORD="*********"
USERNAME="**************"
USER_FULLNAME="*************"
TZ="America/Detroit"
DEBIAN_VERSION="debian-13.2.0-amd64-DVD-1.iso"
KALI_VERSION="kali-linux-2026.2-installer-amd64.iso"

# ------------------------------------------------------------------------------
# 2. COMMAND-LINE FLAG PARSER
# ------------------------------------------------------------------------------
usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -d, --distro <debian|kali>      Select target distro (Default: debian)"
  echo "  -g, --desktop <xfce|gnome|kde> Select desktop environment (Default: Headless/CLI)"
  echo "  -i, --interactive               Prompt for disk selection during setup"
  echo "  -p, --postinstall               Sync core-modules into target post-install"
  echo "  -b, --bypass-menu               Skip boot menu timer and launch installer immediately"
  echo "  -h, --help                      Show this help menu"
  echo ""
  echo "Examples:"
  echo "  $0 --distro debian --bypass-menu"
  echo "  $0 --distro kali --desktop gnome --interactive --postinstall --bypass-menu"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--distro)
      DISTRO="${2,,}" # Convert to lowercase
      shift 2
      ;;
    -g|--desktop)
      DESKTOP_INPUT="${2,,}"
      DEBIAN_DESKTOP="${DESKTOP_INPUT}"
      case "${DESKTOP_INPUT}" in
        xfce|gnome|kde) KALI_DESKTOP="kali-desktop-${DESKTOP_INPUT}" ;;
        *) KALI_DESKTOP="${DESKTOP_INPUT}" ;;
      esac
      shift 2
      ;;
    -i|--interactive)
      INTERACTIVE_DISK="true"
      shift
      ;;
    -p|--postinstall)
      POST_INSTALL="true"
      shift
      ;;
    -b|--bypass-menu)
      BYPASS_MENU="true"
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "[-] ERROR: Unknown argument '$1'"
      usage
      ;;
  esac
done

WORKSPACE="${HOME}/${DISTRO}-custom"
ISO_FILES="${WORKSPACE}/isofiles"
TMP_INITRD="${WORKSPACE}/tmp_initrd"

# ------------------------------------------------------------------------------
# 3. DISTRO, PARTITIONING & POSTINSTALL LOGIC
# ------------------------------------------------------------------------------
# Generate dynamically formatted filename suffix
SUFFIX=""
[ "${INTERACTIVE_DISK}" = "true" ] && SUFFIX="${SUFFIX}-interactive"
[ "${POST_INSTALL}" = "true" ] && SUFFIX="${SUFFIX}-postinstall"
[ "${BYPASS_MENU}" = "true" ] && SUFFIX="${SUFFIX}-nobootmenu"
[ -n "${DESKTOP_INPUT}" ] && SUFFIX="${SUFFIX}-${DESKTOP_INPUT}"
[ -z "${SUFFIX}" ] && SUFFIX="-fullauto"

case "${DISTRO}" in
  debian)
    SOURCE_ISO="${WINDOWS_ISO_DIR}${DEBIAN_VERSION}"
    OUTPUT_DIR="${WINDOWS_ISO_DIR}debian"
    OUTPUT_ISO="${OUTPUT_DIR}/debian-unattended${SUFFIX}.iso"

    MIRROR_HOSTNAME="deb.debian.org"
    MIRROR_DIR="/debian"

    case "${DEBIAN_DESKTOP}" in
      gnome)    TASKSEL_TASKS="task-gnome-desktop";    EXTRA_PKGS="gnome gdm3 xorg" ;;
      kde)      TASKSEL_TASKS="task-kde-desktop";      EXTRA_PKGS="kde-standard sddm xorg" ;;
      cinnamon) TASKSEL_TASKS="task-cinnamon-desktop"; EXTRA_PKGS="cinnamon lightdm xorg" ;;
      mate)     TASKSEL_TASKS="task-mate-desktop";     EXTRA_PKGS="mate-desktop-environment lightdm xorg" ;;
      xfce)     TASKSEL_TASKS="task-xfce-desktop";     EXTRA_PKGS="xfce4 xfce4-goodies lightdm xorg" ;;
      *)
        # HEADLESS / CLI DEFAULT
        TASKSEL_TASKS="standard"
        EXTRA_PKGS=""
        ;;
    esac

    # Common CLI packages for all builds
    EXTRA_PKGS="${EXTRA_PKGS} curl sudo build-essential"
    DM_PRESEED=""
    ;;

  kali)
    SOURCE_ISO="${WINDOWS_ISO_DIR}${KALI_VERSION}"
    OUTPUT_DIR="${WINDOWS_ISO_DIR}kali_builds"
    OUTPUT_ISO="${OUTPUT_DIR}/kali-unattended${SUFFIX}.iso"

    MIRROR_HOSTNAME="http.kali.org"
    MIRROR_DIR="/kali"

    if [ -n "${KALI_DESKTOP}" ]; then
      # GUI INSTALL (When -g flag is used)
      TASKSEL_TASKS="desktop-xfce"
      EXTRA_PKGS="kali-linux-default ${KALI_DESKTOP} lightdm lightdm-gtk-greeter xorg xserver-xorg-video-all dbus-x11 curl sudo build-essential"
      DM_PRESEED="d-i lightdm/default-display-manager select lightdm
d-i shared/default-x-display-manager select lightdm"
    else
      # HEADLESS / CLI DEFAULT (Core tools only, no GUI)
      TASKSEL_TASKS="standard"
      EXTRA_PKGS="kali-linux-headless curl sudo build-essential"
      DM_PRESEED=""
    fi
    ;;

  *)
    echo "[-] ERROR: Unsupported distro '${DISTRO}'. Must be 'debian' or 'kali'."
    exit 1
    ;;
esac

# Partitioning logic
if [ "${INTERACTIVE_DISK}" = "true" ]; then
  PARTITION_CFG="# Partitioning: Interactive disk prompt
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/confirm boolean true"
else
  PARTITION_CFG="# Partitioning: Automated wipe
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true"
fi

# Clean post-install late command logic (staging files without auto-executing)
BASE_LATE_CMD="in-target chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}"

if [ "${POST_INSTALL}" = "true" ]; then
  LATE_CMD="d-i preseed/late_command string ${BASE_LATE_CMD}; in-target mkdir -p /home/docker/core-modules; cp -a /cdrom/custom/core-modules/. /target/home/docker/core-modules/; in-target chown -R ${USERNAME}:${USERNAME} /home/docker/core-modules; in-target chmod -R +x /home/docker/core-modules"
else
  LATE_CMD="d-i preseed/late_command string ${BASE_LATE_CMD}"
fi

# ------------------------------------------------------------------------------
# 4. BUILD EXECUTION
# ------------------------------------------------------------------------------
echo "[+] Starting build for: ${DISTRO^^}"
echo "    - Interactive Disk Selection: ${INTERACTIVE_DISK}"
echo "    - Include Post-Install Sync:  ${POST_INSTALL}"
echo "    - Bypass Boot Menu:          ${BYPASS_MENU}"
if [ "${DISTRO}" = "kali" ]; then
  echo "    - Selected Desktop:           ${KALI_DESKTOP:-None (Headless)}"
fi

echo "[+] Installing build dependencies..."
sudo apt update && sudo apt install -y xorriso cpio gzip

echo "[+] Cleaning previous workspace..."
rm -rf "${WORKSPACE}"
mkdir -p "${ISO_FILES}"

echo "[+] Extracting source ISO: ${SOURCE_ISO}..."
if [ ! -f "${SOURCE_ISO}" ]; then
    echo "[-] ERROR: Source ISO missing at ${SOURCE_ISO}"
    exit 1
fi
xorriso -osirrox on -indev "${SOURCE_ISO}" -extract / "${ISO_FILES}"

# Copy docker core-modules into staging ISO directory if postinstall is enabled
if [ "${POST_INSTALL}" = "true" ]; then
  echo "[+] Syncing docker core modules into ISO staging area..."
  mkdir -p "${ISO_FILES}/custom/core-modules"
  if [ -d "/home/docker/core-modules" ]; then
    cp -r /home/docker/core-modules/. "${ISO_FILES}/custom/core-modules/"
  else
    echo "[-] WARNING: /home/docker/core-modules directory not found on host. Creating empty directory."
  fi
fi

# Modify bootloader configuration if menu bypass is requested
if [ "${BYPASS_MENU}" = "true" ]; then
  echo "[+] Bypassing boot menu timeouts..."

  # ISOLINUX (Legacy BIOS) adjustment
  if [ -f "${ISO_FILES}/isolinux/isolinux.cfg" ]; then
    sed -i 's/default .*/default install/g' "${ISO_FILES}/isolinux/isolinux.cfg"
    sed -i 's/timeout .*/timeout 0/g' "${ISO_FILES}/isolinux/isolinux.cfg"
    sed -i 's/prompt .*/prompt 0/g' "${ISO_FILES}/isolinux/isolinux.cfg"

    if ! grep -q "autoboot" "${ISO_FILES}/isolinux/isolinux.cfg"; then
      echo "autoboot install" >> "${ISO_FILES}/isolinux/isolinux.cfg"
    fi
  fi

  # GRUB (UEFI) adjustment
  if [ -f "${ISO_FILES}/boot/grub/grub.cfg" ]; then
    sed -i 's/set timeout=.*/set timeout=0/g' "${ISO_FILES}/boot/grub/grub.cfg"
    sed -i 's/set default=.*/set default="0"/g' "${ISO_FILES}/boot/grub/grub.cfg"
  fi
fi

echo "[+] Generating preseed configuration..."
cat << EOF > "${WORKSPACE}/preseed.cfg"
# Localization
d-i debian-installer/locale string en_US
d-i keyboard-configuration/xkb-keymap select us

# Network
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string ${DISTRO}-node
d-i netcfg/get_domain string local

# Mirror Settings
d-i apt-setup/use_mirror boolean true
d-i mirror/protocol string http
d-i mirror/country string manual
d-i mirror/http/hostname string ${MIRROR_HOSTNAME}
d-i mirror/http/directory string ${MIRROR_DIR}
d-i mirror/http/proxy string

# Prevent Extra CD Prompts
d-i apt-setup/cdrom/set-first boolean false
d-i apt-setup/cdrom/set-next boolean false
d-i apt-setup/cdrom/set-failed boolean false
d-i apt-setup/disable-cdrom-entries boolean true

# Accounts
d-i passwd/root-login boolean false
d-i passwd/user-fullname string ${USER_FULLNAME}
d-i passwd/username string ${USERNAME}
d-i passwd/user-password password ${USER_PASSWORD}
d-i passwd/user-password-again password ${USER_PASSWORD}

# Clock & Time
d-i clock-setup/utc boolean true
d-i time/zone string ${TZ}
d-i clock-setup/ntp boolean true

${PARTITION_CFG}

${DM_PRESEED}

# =====================================================================
# PACKAGE SELECTION
# =====================================================================
d-i tasksel/first multiselect ${TASKSEL_TASKS}
d-i pkgsel/include string ${EXTRA_PKGS}
d-i pkgsel/upgrade select none
d-i popularity-contest/participate boolean false

# Bootloader
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i grub-installer/bootdev string default

# Post-Install Action
${LATE_CMD}

# Auto Reboot
d-i finish-install/reboot_in_progress note
EOF

echo "[+] Injecting preseed into initrd..."
mkdir -p "${TMP_INITRD}"
cd "${TMP_INITRD}"
gzip -d < "${ISO_FILES}/install.amd/initrd.gz" | cpio --extract --make-directories --no-absolute-filenames --unconditional 2>/dev/null || true
cp "${WORKSPACE}/preseed.cfg" ./preseed.cfg
find . | cpio -H newc --create 2>/dev/null | gzip -9 > "${ISO_FILES}/install.amd/initrd.gz"

cd "${WORKSPACE}"
sudo rm -rf "${TMP_INITRD}"

echo "[+] Updating integrity hashes..."
chmod +w "${ISO_FILES}/md5sum.txt"
(cd "${ISO_FILES}" && find . -type f ! -name "md5sum.txt" ! -path "./isolinux/*" -exec md5sum {} + > md5sum.txt)

echo "[+] Ensuring output directory exists..."
mkdir -p "${OUTPUT_DIR}"

echo "[+] Compiling hybrid bootable ISO..."
xorriso -as mkisofs \
  -r -V "${DISTRO^^}_UNAT" \
  -o "${OUTPUT_ISO}" \
  -J -joliet-long \
  -b isolinux/isolinux.bin \
  -c isolinux/boot.cat \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot \
  -e boot/grub/efi.img \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  "${ISO_FILES}"

echo "=============================================================================="
echo "[+] SUCCESS! Output generated at:"
echo "    ${OUTPUT_ISO}"
echo "=============================================================================="
