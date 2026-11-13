#!/bin/bash
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710

echo "########## A. source-device fstab.qcom (HyperOS pudding) ##########"
rm -rf /tmp/vbf && mkdir -p /tmp/vbf && cd /tmp/vbf
cpio -idm --no-absolute-filenames 'first_stage_ramdisk/fstab.qcom' < /tmp/vb_rd.cpio 2>/dev/null
grep -vE '^\s*#|^\s*$' first_stage_ramdisk/fstab.qcom | head -40

echo "########## B. WSL selinuxfs support ##########"
grep -E 'selinuxfs|binder' /proc/filesystems || echo "(no selinuxfs in /proc/filesystems)"
mount -t selinuxfs selinuxfs /mnt 2>&1 | head -2; umount /mnt 2>/dev/null
echo "--- binfmt ---"
ls /proc/sys/fs/binfmt_misc/ 2>&1 | head -5

echo "########## C. kernel skip_initramfs handling ##########"
grep -rn 'skip_initramfs' $K/init/ $K/arch/arm64/ 2>/dev/null | head -10

echo "########## D. ramdisk bootstrap dirs ##########"
rm -rf /tmp/saroot && mkdir -p /tmp/saroot && cd /tmp/saroot
cpio -idm --no-absolute-filenames < $D/ib/ramdisk.cpio 2>/dev/null
echo "--- apex/bootstrap dirs present? ---"
for d in apex bootstrap-apex linkercache linkerconfig mnt metadata second_stage_resources debug_ramdisk; do
  [ -d "$d" ] && echo "  $d/ EXISTS" || echo "  $d/ missing"
done
echo DONE_SB
