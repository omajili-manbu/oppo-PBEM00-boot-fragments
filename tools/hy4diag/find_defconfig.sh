#!/bin/bash
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710
echo "===== find pbem00_defconfig ====="
find $K -maxdepth 4 -name 'pbem00*' 2>/dev/null | head -5
echo
echo "===== how was out/.config produced (build script clue) ====="
grep -h 'defconfig' /home/qwe12/oppo-pbem00-kernel/_build_testh26.sh 2>/dev/null | head -3
grep -rn 'pbem00' /home/qwe12/oppo-pbem00-kernel/_build_testh26.sh 2>/dev/null | head -5
echo
echo "===== vendor defconfig merge (OPLUS =y trick) ====="
ls $K/arch/arm64/configs/vendor/ 2>/dev/null
echo
echo "===== PBEM00.config full ====="
cat $K/arch/arm64/configs/vendor/oplus/PBEM00.config
