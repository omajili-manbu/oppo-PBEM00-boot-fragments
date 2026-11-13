#!/bin/bash
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
M=/tmp/imgmnt; mkdir -p $M
mountpoint -q $M || mount -o loop,ro $IMG $M

echo "########## A. magiskinit strings: paths / exec / exit ##########"
strings -a $D/b1/rd/init | grep -E '/system_root|/system/bin/init|system/bin/init|Legacy SAR|/sbin|chroot|2SI|skip_initramfs|magiskinit' | head -30

echo "########## B. bootstrap linker --list (real namespace logic) ##########"
timeout 60 unshare -m -p -f --propagation private bash -c '
  exec chroot /tmp/imgmnt /system/bin/bootstrap/linker64 --list /system/bin/init
' 2>&1 | head -40

echo "########## C. run magiskinit in sandbox (fake cmdline + image at /system_root) ##########"
printf '%s\n' 'console=ttyMSM0,115200n8 androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.configfs=true androidboot.usbcontroller=a600000.dwc3 swiotlb=1 loop.max_part=7 buildvariant=user androidboot.selinux=permissive panic=30 watchdog_v2.enable=0 root=/dev/block/platform/soc/1d84000.ufshc/by-name/system skip_initramfs loglevel=8 ignore_loglevel oops=panic softlockup_panic=1 usbwait=10' > /tmp/fake_cmdline
rm -rf /tmp/mroot && mkdir -p /tmp/mroot && cd /tmp/mroot
cpio -idm --no-absolute-filenames < $D/b1/ramdisk.cpio 2>/dev/null
mkdir -p system_root
dmesg -C 2>/dev/null
timeout 40 unshare -m -p -f --propagation private bash -c '
  mount --bind /tmp/fake_cmdline /proc/cmdline
  mount --bind /tmp/imgmnt /tmp/mroot/system_root
  cd /tmp/mroot
  exec chroot /tmp/mroot /init > /tmp/magiskinit.log 2>&1
'; echo "EXIT=$?"
echo "--- magiskinit stdout/stderr ---"
head -30 /tmp/magiskinit.log 2>/dev/null
echo "--- dmesg tail ---"
dmesg 2>/dev/null | tail -25
umount $M
echo DONE_SB3
