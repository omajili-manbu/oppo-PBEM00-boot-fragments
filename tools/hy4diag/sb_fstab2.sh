#!/bin/bash
# usage: sb_fstab2.sh <mount_point>
MP="${1:-/}"
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img

for l in $(losetup -a | grep -F "$IMG" | cut -d: -f1); do losetup -d $l; done
LOOP=$(losetup -f --show -r $IMG); echo "LOOP=$LOOP mp=$MP"
printf 'system %s ext4 ro,barrier=1 wait,first_stage_mount\n' "$MP" > /tmp/fstab.qcom
cat /tmp/fstab.qcom

dmesg -C 2>/dev/null
timeout -k 5 40 unshare -m -p -f --kill-child --propagation private bash -c '
  # isolated /dev with just what init needs
  mount -t tmpfs tmpfs /tmp/saroot/dev
  mknod /tmp/saroot/dev/null c 1 3
  mknod /tmp/saroot/dev/zero c 1 5
  mknod /tmp/saroot/dev/urandom c 1 9
  mknod /tmp/saroot/dev/random c 1 8
  mknod /tmp/saroot/dev/kmsg c 1 11
  mknod /tmp/saroot/dev/ptmx c 5 2
  touch /tmp/saroot/dev/loopnode
  mount --bind '"$LOOP"' /tmp/saroot/dev/loopnode
  cp /tmp/fstab.qcom /tmp/saroot/fstab.qcom
  exec chroot /tmp/saroot /qemu-aarch64-static -strace /init
' > /tmp/trace_$$.txt 2>&1
echo "rc=$?"
echo "===== init kernel log ====="
dmesg 2>/dev/null | grep -aE 'init:|fstab|apex|SELinux|selinux|mount' | tail -40
echo "===== last trace lines ====="
grep -aE 'mount\(|openat.*(fstab|system)|execve|exit_group|write\(2,' /tmp/trace_$$.txt | tail -30
losetup -d $LOOP 2>/dev/null
echo DONE_MP
