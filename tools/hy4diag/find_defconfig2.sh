#!/bin/bash
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710
echo "===== who defines pbem00_defconfig target ====="
grep -rn 'pbem00' $K/Makefile $K/arch/arm64/Makefile $K/arch/arm64/configs/Makefile 2>/dev/null | head -5
grep -rln 'pbem00' $K/scripts/kconfig/ 2>/dev/null | head
grep -rn 'PBEM00.config\|vendor/oplus' $K/arch/arm64/configs/Makefile $K/scripts/kconfig/Makefile 2>/dev/null | head -5
echo
echo "===== kconfig frag merge mechanism (kconfigfragments?) ====="
grep -rn 'defconfig' $K/scripts/kconfig/Makefile | head -10
echo
echo "===== last build log: how config was generated ====="
tail -40 /tmp/cfg24.log 2>/dev/null | head -10
ls -la $K/out/.config $K/out/config.log 2>/dev/null
echo
echo "===== search whole tree (excluding .git) ====="
grep -rln 'pbem00_defconfig' $K --include='Makefile' --include='*.mk' --include='Kconfig' 2>/dev/null | grep -v '\.git' | head -5
