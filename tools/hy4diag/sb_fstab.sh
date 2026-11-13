#!/bin/bash
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img

# loop device for the merged image (read-only)
for l in $(losetup -a | grep -F "$IMG" | cut -d: -f1); do losetup -d $l; done
LOOP=$(losetup -f --show -r $IMG); echo "LOOP=$LOOP"

# sandbox root = ROM first-stage ramdisk
rm -rf /tmp/saroot && mkdir -p /tmp/saroot && cd /tmp/saroot
cpio -idm --no-absolute-filenames < $D/ib/ramdisk.cpio 2>/dev/null
cp -f /usr/bin/qemu-aarch64-static /tmp/saroot/qemu-aarch64-static 2>/dev/null || cp -f /usr/bin/qemu-aarch64 /tmp/saroot/qemu-aarch64-static

run_case() {
  local name="$1" mp="$2"
  printf 'system %s ext4 ro,barrier=1 wait,first_stage_mount\n' "$mp" > /tmp/saroot/fstab.qcom
  echo "########## CASE $name : mount point '$mp' ##########"
  dmesg -C 2>/dev/null
  timeout 45 unshare -m -p -f --propagation private bash -c '
    exec chroot /tmp/saroot /qemu-aarch64-static -strace /init
  ' > /tmp/case_$name.trace 2>&1
  echo "rc=$?"
  echo "--- key syscalls/log lines ---"
  grep -aoE '(write\([0-9]+, "[^"]{6,160}"|mount\("[^"]*", "[^"]*"|openat\([^)]*fstab[^)]*\)[^=]*= -[0-9]+|exit_group\([0-9]+\))' /tmp/case_$name.trace | tail -45
  echo "--- dmesg (init) ---"
  dmesg 2>/dev/null | tail -15
}

run_case A_root "/"
run_case B_system "/system"

losetup -d $LOOP 2>/dev/null
echo DONE_FSTAB
