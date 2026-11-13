#!/bin/bash
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img

echo "########## 1. vendor ramdisk fstab.qcom ##########"
lz4 -d -c $D/vb/ramdisk.cpio > /tmp/vb_rd.cpio 2>/dev/null
rm -rf /tmp/vbf && mkdir -p /tmp/vbf && cd /tmp/vbf
cpio -idm --no-absolute-filenames 'first_stage_ramdisk/fstab.qcom' < /tmp/vb_rd.cpio 2>/dev/null
grep -vE '^\s*#|^\s*$' first_stage_ramdisk/fstab.qcom | head -30

echo "########## 2. INITRAMFS_IGNORE_SKIP_FLAG ##########"
grep -rn 'INITRAMFS_IGNORE_SKIP_FLAG' $K/arch/arm64/configs/ $K/init/Kconfig 2>/dev/null | head -5

echo "########## 3. direct exec: /system/bin/init on merged image root ##########"
M=/tmp/imgmnt; mkdir -p $M
mountpoint -q $M || mount -o loop,ro $IMG $M || { echo MOUNTFAIL; exit 1; }
dmesg -C 2>/dev/null
timeout 60 unshare -m -p -f --propagation private bash -c '
  exec chroot /tmp/imgmnt /system/bin/init > /tmp/direct_init.log 2>&1
' ; echo "EXIT=$?"
echo "--- stdout/stderr ---"; head -40 /tmp/direct_init.log 2>/dev/null
echo "--- kernel log (init lines) ---"; dmesg 2>/dev/null | grep -iE 'init|selinux|apex|fstab|mount' | head -40
umount $M
echo DONE_SB2
