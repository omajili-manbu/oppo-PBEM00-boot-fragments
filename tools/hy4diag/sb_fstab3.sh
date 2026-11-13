#!/bin/bash
# usage: sb_fstab3.sh <mount_point>
MP="${1:-/}"
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
R=/root/saroot

for l in $(losetup -a | grep -F "$IMG" | cut -d: -f1); do losetup -d $l; done
LOOP=$(losetup -f --show -r $IMG); echo "LOOP=$LOOP mp=$MP"

rm -rf $R && mkdir -p $R && cd $R
cpio -idm --no-absolute-filenames < $D/ib/ramdisk.cpio 2>/dev/null
cp -f /usr/bin/qemu-aarch64-static $R/qemu-aarch64-static
qemu-aarch64-static --version 2>/dev/null | head -1
printf 'system %s ext4 ro,barrier=1 wait,first_stage_mount\n' "$MP" > $R/fstab.qcom
echo "--- fstab ---"; cat $R/fstab.qcom

dmesg -C 2>/dev/null
timeout -k 5 40 unshare -m -p -f --kill-child --propagation private bash -c '
  mount -t tmpfs tmpfs '"$R"'/dev
  for n in "null c 1 3" "zero c 1 5" "urandom c 1 9" "random c 1 8" "kmsg c 1 11" "ptmx c 5 2"; do
    set -- $n; mknod '"$R"'/dev/$1 $2 $3 $4 2>/dev/null
  done
  touch '"$R"'/dev/loopnode; mount --bind '"$LOOP"' '"$R"'/dev/loopnode
  exec chroot '"$R"' /qemu-aarch64-static -strace /init
' > /tmp/trace_mp.txt 2>&1
echo "rc=$?"
echo "===== init kernel log ====="
dmesg 2>/dev/null | grep -aE 'init:|fstab|apex|SELinux|selinux' | tail -40
echo "===== trace: key lines ====="
grep -aE 'mount\(|fstab|execve|exit_group' /tmp/trace_mp.txt | tail -25
echo "===== trace tail ====="
tail -8 /tmp/trace_mp.txt
losetup -d $LOOP 2>/dev/null
echo DONE_MP
