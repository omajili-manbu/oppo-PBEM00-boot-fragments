#!/bin/bash
PKG='/mnt/e/work/oppo-pbem00-kernel/小米6_HyperOS 4.0.30.0.XPCCNXM_pudding_一键刷入'
C=/mnt/c/hy4work
mkdir -p $C/ota
unzip -o -q "$PKG/zip/HyperOS 3 W-OTA-8 simplified.zip" 'META-INF/com/android/*' 'META-INF/com/google/android/*' 'install/*' -d $C/ota
echo "===== metadata ====="
cat $C/ota/META-INF/com/android/metadata
echo
echo "===== updater-script ====="
cat $C/ota/META-INF/com/google/android/updater-script
echo
echo "===== update-binary: device check / asserts ====="
strings -a $C/ota/META-INF/com/google/android/update-binary | grep -aiE 'assert|sagit|mido|device|msm8998|getprop' | head -20
echo
echo "===== backuptool ====="
head -30 $C/ota/install/bin/backuptool.sh 2>/dev/null
echo DONE_META
