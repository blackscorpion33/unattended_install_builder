#!/usr/bin/env bash
# ==============================================================================
# UNIVERSAL UNATTENDED ISO GENERATOR (Debian / Kali)
# ==============================================================================

set -e

# ------------------------------------------------------------------------------
# 1. DEFAULT CONFIGURATION VARIABLES
# ------------------------------------------------------------------------------
DISTRO="debian"
DESKTOP_INPUT=""
KALI_DESKTOP="kali-desktop-xfce"
INTERACTIVE_DISK="false"
POST_INSTALL="false"
BYPASS_MENU="false"

WINDOWS_ISO_DIR="/mnt/e/iso"

USER_PASSWORD="your_password"
USERNAME="your_username"
USER_FULLNAME="your_real_name"
TZ="America/Detroit"

DEBIAN_VERSION="debian-13.2.0-amd64-DVD-1.iso"
KALI_VERSION="kali-linux-2026.2-installer-amd64.iso"

NODE_HOST="debianxxx" #set to your desired hostname
NODE_IP="192.168.1.xxx" #set to you desired ip address

# ------------------------------------------------------------------------------
# 2. COMMAND-LINE FLAG PARSER
# ------------------------------------------------------------------------------
usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -d, --distro <debian|kali>"
  echo "  -g, --desktop <xfce|gnome|kde|mate|lxde|lxqt|cinnamon>"
  echo "  -i, --interactive"
  echo "  -p, --postinstall"
  echo "  -b, --bypass-menu"
  echo "  -h, --help"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--distro)
      DISTRO="${2,,}"
      shift 2
      ;;
    -g|--desktop)
      DESKTOP_INPUT="${2,,}"
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
SUFFIX=""

# Add desktop tag for Debian
if [ "${DISTRO}" = "debian" ] && [ -n "${DESKTOP_INPUT}" ]; then
  SUFFIX="${SUFFIX}-${DESKTOP_INPUT}"
fi

# Add desktop tag for Kali
if [ "${DISTRO}" = "kali" ]; then
  DT_SHORT="${KALI_DESKTOP#kali-desktop-}"
  SUFFIX="${SUFFIX}-${DT_SHORT}"
fi

[ "${INTERACTIVE_DISK}" = "true" ] && SUFFIX="${SUFFIX}-interactive"
[ "${POST_INSTALL}" = "true" ] && SUFFIX="${SUFFIX}-postinstall"
[ "${BYPASS_MENU}" = "true" ] && SUFFIX="${SUFFIX}-nobootmenu"

[ -z "${SUFFIX}" ] && SUFFIX="-fullauto"

case "${DISTRO}" in
  debian)
    SOURCE_ISO="${WINDOWS_ISO_DIR}/${DEBIAN_VERSION}"
    OUTPUT_DIR="${WINDOWS_ISO_DIR}/debian"
    OUTPUT_ISO="${OUTPUT_DIR}/debian-unattended${SUFFIX}.iso"
    MIRROR_HOSTNAME="deb.debian.org"
    MIRROR_DIR="/debian"

    # Debian desktop mapping
    case "${DESKTOP_INPUT}" in
      gnome)
        TASKSEL_TASKS="gnome-desktop"
        EXTRA_PKGS="gnome-core gdm3 build-essential curl sudo"
        DM_NAME="gdm3"
        ;;
      kde)
        TASKSEL_TASKS="kde-desktop"
        EXTRA_PKGS="kde-standard sddm build-essential curl sudo"
        DM_NAME="sddm"
        ;;
      xfce)
        TASKSEL_TASKS="xfce-desktop"
        EXTRA_PKGS="xfce4 lightdm lightdm-gtk-greeter build-essential curl sudo"
        DM_NAME="lightdm"
        ;;
      cinnamon)
        TASKSEL_TASKS="cinnamon-desktop"
        EXTRA_PKGS="cinnamon gdm3 build-essential curl sudo"
        DM_NAME="gdm3"
        ;;
      mate)
        TASKSEL_TASKS="mate-desktop"
        EXTRA_PKGS="mate-desktop-environment lightdm build-essential curl sudo"
        DM_NAME="lightdm"
        ;;
      lxqt)
        TASKSEL_TASKS="lxqt-desktop"
        EXTRA_PKGS="lxqt sddm build-essential curl sudo"
        DM_NAME="sddm"
        ;;
      lxde)
        TASKSEL_TASKS="lxde-desktop"
        EXTRA_PKGS="lxde lightdm build-essential curl sudo"
        DM_NAME="lightdm"
        ;;
      *)
        TASKSEL_TASKS="standard, ssh-server"
        EXTRA_PKGS="build-essential curl sudo"
        DM_NAME=""
        ;;
    esac

    if [ -n "${DM_NAME}" ]; then
      DM_PRESEED="d-i ${DM_NAME}/default-display-manager select ${DM_NAME}
d-i shared/default-x-display-manager select ${DM_NAME}"
    else
      DM_PRESEED=""
    fi
    ;;

  kali)
    SOURCE_ISO="${WINDOWS_ISO_DIR}/${KALI_VERSION}"
    OUTPUT_DIR="${WINDOWS_ISO_DIR}/kali_builds"
    OUTPUT_ISO="${OUTPUT_DIR}/kali-unattended${SUFFIX}.iso"
    MIRROR_HOSTNAME="http.kali.org"
    MIRROR_DIR="/kali"

    case "${KALI_DESKTOP}" in
      kali-desktop-gnome)
        TASKSEL_TASKS="desktop-gnome"
        DESKTOP_PKG="kali-desktop-gnome"
        DM_PKG="gdm3"
        DM_NAME="gdm3"
        ;;
      kali-desktop-kde)
        TASKSEL_TASKS="desktop-kde"
        DESKTOP_PKG="kali-desktop-kde"
        DM_PKG="sddm plasma-workspace"
        DM_NAME="sddm"
        ;;
      *)
        TASKSEL_TASKS="desktop-xfce"
        DESKTOP_PKG="kali-desktop-xfce"
        DM_PKG="lightdm lightdm-gtk-greeter"
        DM_NAME="lightdm"
        ;;
    esac

    EXTRA_PKGS="kali-linux-default ${DESKTOP_PKG} ${DM_PKG} xorg xserver-xorg-video-all dbus-x11 curl sudo build-essential"

    DM_PRESEED="d-i ${DM_NAME}/default-display-manager select ${DM_NAME}
d-i shared/default-x-display-manager select ${DM_NAME}"
    ;;

  *)
    echo "[-] ERROR: Unsupported distro '${DISTRO}'."
    exit 1
    ;;
esac

# Partitioning logic
if [ "${INTERACTIVE_DISK}" = "true" ]; then
  PARTITION_CFG="d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/confirm boolean true"
else
  PARTITION_CFG="d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true"
fi

### uncomment and adjust paths to build your own files into the builder
#BASE_LATE_CMD="in-target chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}"

#if [ "${POST_INSTALL}" = "true" ]; then
#  LATE_CMD="d-i preseed/late_command string ${BASE_LATE_CMD}; in-target mkdir -p /home/docker/core-modules; cp -a /cdrom/custom/core-modules/. /target/home/docker/core-modules/; in-target chown -R ${USERNAME}:${USERNAME} /home/docker/core-modules; in-target chmod -R +x /home/docker/core-modules"
#else
#  LATE_CMD="d-i preseed/late_command string ${BASE_LATE_CMD}"
#fi

# ------------------------------------------------------------------------------
# 4. BUILD EXECUTION
# ------------------------------------------------------------------------------
echo "[+] Starting build for: ${DISTRO^^}"
echo "    - Desktop: ${DESKTOP_INPUT:-none}"
echo "    - Interactive Disk: ${INTERACTIVE_DISK}"
echo "    - Postinstall: ${POST_INSTALL}"
echo "    - Bypass Menu: ${BYPASS_MENU}"

sudo apt update && sudo apt install -y xorriso cpio gzip

rm -rf "${WORKSPACE}"
mkdir -p "${ISO_FILES}"

echo "[+] Extracting source ISO..."
xorriso -osirrox on -indev "${SOURCE_ISO}" -extract / "${ISO_FILES}"

if [ "${POST_INSTALL}" = "true" ]; then
  mkdir -p "${ISO_FILES}/custom/core-modules"
  cp -r /home/docker/core-modules/. "${ISO_FILES}/custom/core-modules/" || true
fi

if [ "${BYPASS_MENU}" = "true" ]; then
  if [ -f "${ISO_FILES}/isolinux/isolinux.cfg" ]; then
    sed -i 's/default .*/default install/g' "${ISO_FILES}/isolinux/isolinux.cfg"
    sed -i 's/timeout .*/timeout 0/g' "${ISO_FILES}/isolinux/isolinux.cfg"
    sed -i 's/prompt .*/prompt 0/g' "${ISO_FILES}/isolinux/isolinux.cfg"
  fi

  if [ -f "${ISO_FILES}/boot/grub/grub.cfg" ]; then
    sed -i 's/set timeout=.*/set timeout=0/g' "${ISO_FILES}/boot/grub/grub.cfg"
    sed -i 's/set default=.*/set default="0"/g' "${ISO_FILES}/boot/grub/grub.cfg"
  fi
fi

echo "[+] Generating preseed..."
cat << EOF > "${WORKSPACE}/preseed.cfg"
# ------------------------------------------------------------------------------
# NON-INTERACTIVE AUTOMATION OVERRIDES
# ------------------------------------------------------------------------------
d-i debian-installer/locale string en_US.UTF-8
d-i console-setup/ask_detect boolean false
d-i keyboard-configuration/xkb-keymap select us

# Prevent CD-ROM scanning prompts and disable additional CD checks
d-i apt-setup/cdrom/set-first boolean false
d-i apt-setup/cdrom/set-next boolean false
d-i apt-setup/cdrom/set-failed boolean false
d-i apt-setup/disable-cdrom-entries boolean true
d-i apt-setup/services-select multiselect security, updates

# Network Setup
# Network Setup (Static IP)
d-i netcfg/disable_dhcp boolean true
d-i netcfg/choose_interface select auto

d-i netcfg/get_ipaddress string ${NODE_IP}
d-i netcfg/get_netmask string 255.255.255.0
d-i netcfg/get_gateway string 192.168.1.1
d-i netcfg/get_nameservers string 1.1.1.1 1.0.0.1
d-i netcfg/confirm_static boolean true

d-i netcfg/get_hostname string ${NODE_HOST}
d-i netcfg/get_domain string local
d-i netcfg/wireless_wep string

# Mirror Settings
d-i apt-setup/use_mirror boolean true
d-i mirror/protocol string http
d-i mirror/country string manual
d-i mirror/http/hostname string ${MIRROR_HOSTNAME}
d-i mirror/http/directory string ${MIRROR_DIR}
d-i mirror/http/proxy string

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

# Package Selection & Desktop
# Package Selection & Desktop
tasksel tasksel/first multiselect ${TASKSEL_TASKS}
d-i pkgsel/upgrade select none
popularity-contest popularity-contest/participate boolean false

# ============================================================
# Packages & Post-install Gitea execution
# ============================================================

# Base APT Packages + Environment Variables Combined
d-i pkgsel/include string ${EXTRA_PKGS} \
    wireguard curl wget ca-certificates gnupg lsb-release tcpdump \
    bind9-dnsutils git unzip zip rsync jq net-tools btop cifs-utils \
    age grep sed qrencode python3-pylast python3-pip \
    sqlite3 ncdu iotop samba rsyslog python3-flask pv

# Gitea Post-Install Execution
#d-i preseed/late_command string \
#    in-target git clone https://YOUR_TOKEN@gitea.yourdomain.com/youruser/postinstall.git /tmp/postinstall; \
#    in-target chmod +x /tmp/postinstall/setup.sh; \
#    in-target /tmp/postinstall/setup.sh; \
#    in-target rm -rf /tmp/postinstall

# Bootloader (Suppress drive selection prompt)
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i grub-installer/bootdev string default

# Post-Install Action & Auto Reboot
${LATE_CMD}
d-i finish-install/reboot_in_progress note
EOF

echo "[+] Injecting preseed..."
mkdir -p "${TMP_INITRD}"
cd "${TMP_INITRD}"
gzip -d < "${ISO_FILES}/install.amd/initrd.gz" | cpio --extract --make-directories --no-absolute-filenames --unconditional
cp "${WORKSPACE}/preseed.cfg" ./preseed.cfg
sudo bash -c "find . | cpio -H newc --create | gzip -9 > '${ISO_FILES}/install.amd/initrd.gz'"
cd "${WORKSPACE}"
sudo rm -rf "${TMP_INITRD}"

chmod +w "${ISO_FILES}/md5sum.txt"
(cd "${ISO_FILES}" && find . -type f ! -name "md5sum.txt" ! -path "./isolinux/*" -exec md5sum {} + > md5sum.txt)

mkdir -p "${OUTPUT_DIR}"

echo "[+] Building ISO..."
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
