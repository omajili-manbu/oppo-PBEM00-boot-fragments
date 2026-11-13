#!/bin/bash
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
echo "########## 1. our DTB: has android,fstab? ##########"
dtc -I dtb -O dts $D/b1/kernel_dtb 2>/dev/null > /root/our.dts
echo "dts lines: $(wc -l < /root/our.dts)"
echo "--- android,fstab ---"; grep -c 'android,fstab' /root/our.dts
echo "--- fstab node ---"; grep -n -A5 'fstab' /root/our.dts | head -20
echo "--- chosen ---"; grep -n -A8 'chosen {' /root/our.dts | head -14

echo
echo "########## 2. our DTB source in kernel tree? ##########"
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710
ls $K/arch/arm64/boot/dts/oplus/ 2>/dev/null | head -10
find $K/arch/arm64/boot/dts -iname '*pbem00*' 2>/dev/null | head -5
find $K/arch/arm64/boot/dts -iname '*sdm670*' 2>/dev/null | head -8

echo
echo "########## 3. does our DTB contain 'firmware/android'? ##########"
grep -c 'firmware' /root/our.dts
grep -n 'firmware' /root/our.dts | head -5
echo DONE_DTB
