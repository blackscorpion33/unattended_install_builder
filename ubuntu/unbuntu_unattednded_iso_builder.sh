#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Ubuntu Server Autoinstall ISO Builder
# ============================================================

ISO_IN="/mnt/e/iso/ubuntu/ubuntu-26.04-live-server-amd64.iso"
OUT_DIR="/mnt/e/iso/ubuntu/complete"
ISO_OUT="${OUT_DIR}/ubuntu-server-preseed.iso"
WORKDIR="iso-work"
YAML_FILE="/mnt/e/iso/ubuntu/autoinstall.yaml"

[[ -f "$ISO_IN" ]] || { echo "Missing $ISO_IN"; exit 1; }
[[ -f "$YAML_FILE" ]] || { echo "Missing $YAML_FILE"; exit 1; }

echo ">>> Cleaning workspace..."
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

# Ensure workspace cleanup on script exit or interruption
trap 'echo ">>> Cleaning up working directory..."; rm -rf "$WORKDIR"' EXIT

echo ">>> Extracting original ISO contents..."
xorriso -osirrox on -indev "$ISO_IN" -extract / "$WORKDIR" >/dev/null 2>&1
chmod -R u+w "$WORKDIR"

mkdir -p "$WORKDIR/postinstall"
cp -r /mnt/e/iso/ubuntu/core-modules "$WORKDIR/postinstall/"

echo ">>> Embedding autoinstall config..."
mkdir -p "$WORKDIR/nocloud" "$WORKDIR/autoinstall"

for TARGET_DIR in "$WORKDIR/nocloud" "$WORKDIR/autoinstall"; do
    {
        echo "#cloud-config"
        grep -v '^#cloud-config' "$YAML_FILE"
    } > "$TARGET_DIR/user-data"

    touch "$TARGET_DIR/meta-data" "$TARGET_DIR/vendor-data"
done

echo ">>> Prepending Automated Entry to GRUB..."
GRUB_CFG="$WORKDIR/boot/grub/grub.cfg"

if [[ -f "$GRUB_CFG" ]]; then
    TMP_GRUB=$(mktemp)
    cat << 'EOF' > "$TMP_GRUB"
set timeout=2
set default=0

menuentry "Automated Unattended Installation" {
    set gfxpayload=keep
    linux /casper/vmlinuz quiet nomultipath autoinstall "ds=nocloud;s=/cdrom/nocloud" cloud-config-url=/dev/null ---
    initrd /casper/initrd
}

EOF
    cat "$GRUB_CFG" >> "$TMP_GRUB"
    mv "$TMP_GRUB" "$GRUB_CFG"
fi

echo ">>> Building new ISO using raw interval mapping..."
mkdir -p "$OUT_DIR"
rm -f "$ISO_OUT"

xorriso -as mkisofs -r \
  -V "UBUNTU_AUTOINSTALL" \
  -o "$ISO_OUT" \
  --grub2-mbr \
  --interval:local_fs:0s-15s:zero_mbrpt,zero_gpt:"$ISO_IN" \
  -partition_offset 16 \
  --mbr-force-bootable \
  -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b --interval:local_fs:0s-0s:zero_mbrpt,zero_gpt:"$ISO_IN" \
  -appended_part_as_gpt \
  -iso_mbr_part_type 0x02 \
  -c boot.catalog \
  -b boot/grub/i386-pc/eltorito.img \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot \
  -e '--interval:appended_partition_2:all::' \
  -no-emul-boot \
  "$WORKDIR"

echo ">>> DONE!"
echo "Created: $ISO_OUT"
