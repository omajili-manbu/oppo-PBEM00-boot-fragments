#!/bin/bash
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
R=/root/ramtest2

sed 's|/sys/class/block/sda11/dev|/sys/class/block/loop0/dev|' $D/shim.c > /root/shim_test2.c
aarch64-linux-gnu-gcc -static -O2 -o /root/shim_test2 /root/shim_test2.c 2>/dev/null
ls -l /root/shim_test2

rm -rf $R; mkdir -p $R; cd $R
cpio -idm --no-absolute-filenames < $D/ramdisk_hy4.cpio 2>/dev/null
rm -f init; cp /root/shim_test2 init; chmod 0750 init
echo "ramdisk: $(ls | tr '\n' ' '); pol=$(find pol -type f | wc -l)"

for l in $(losetup -a | grep -F "$IMG" | cut -d: -f1); do losetup -d $l; done
LOOP=$(losetup -f --show -r $IMG); echo "LOOP=$LOOP  sysdev=$(cat /sys/class/block/loop0/dev 2>/dev/null)"
dmesg -C 2>/dev/null
timeout -k 5 70 unshare -m -p -f --kill-child --propagation private bash -c '
  exec chroot '"$R"' /init
' > /tmp/shim2.log 2>&1
echo "rc=$?"
echo "===== shim + init log ====="
dmesg 2>/dev/null | grep -aE 'hy4shim|init:|selinux' | head -40
echo "===== stderr ====="
head -15 /tmp/shim2.log
losetup -d $LOOP 2>/dev/null
echo DONE_SHIM2
