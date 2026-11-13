#!/bin/bash
PKG='/mnt/e/work/oppo-pbem00-kernel/小米6_HyperOS 4.0.30.0.XPCCNXM_pudding_一键刷入'
C=/mnt/c/hy4work

echo "########## 1. OTA metadata: who declares what ##########"
cd "$C/ota" 2>/dev/null || { unzip -o -q "$PKG/zip/HyperOS 3 W-OTA-8 simplified.zip" 'META-INF/*' 'install/*' -d "$C/ota"; }
cat $C/ota/META-INF/com/android/metadata 2>/dev/null
echo '--- updater-script ---'
cat $C/ota/META-INF/com/google/android/updater-script 2>/dev/null
echo
echo '--- update-binary head 60 lines ---'
head -60 $C/ota/META-INF/com/google/android/update-binary 2>/dev/null | strings | head -40

echo
echo "########## 2. vendor.img: phh-treble fingerprints? ##########"
mkdir -p /mnt/m6v
mountpoint -q /mnt/m6v || mount -o loop,ro $C/ota/vendor.img /mnt/m6v
echo "--- root ---"
ls /mnt/m6v | tr '\n' ' '; echo
echo "--- phh markers ---"
ls -d /mnt/m6v/phh* /mnt/m6v/linkerconfig/phh* 2>/dev/null
ls /mnt/m6v/bin/phh* /mnt/m6v/etc/phh* 2>/dev/null | head
grep -rl 'phh' /mnt/m6v/build.prop 2>/dev/null
echo "--- vendor identity props ---"
grep -hE '^ro.product.vendor.(brand|device|name|model)=|^ro.product.device=|^ro.build.product=' /mnt/m6v/build.prop 2>/dev/null | head -8
echo "--- board/platform ---"
grep -hE '^ro.board.platform=|^ro.vendor.qti|^ro.soc' /mnt/m6v/build.prop 2>/dev/null | head -5
echo "--- init rc count / first entries ---"
ls /mnt/m6v/etc/init/ 2>/dev/null | wc -l
ls /mnt/m6v/etc/init/ 2>/dev/null | head -10
echo "--- treble VNDK / linkerconfig ---"
grep -hE '^ro.vndk|^ro.vendor.vndk' /mnt/m6v/build.prop /mnt/m6v/etc/*.prop 2>/dev/null | head -4
umount /mnt/m6v 2>/dev/null
echo DONE_ID
