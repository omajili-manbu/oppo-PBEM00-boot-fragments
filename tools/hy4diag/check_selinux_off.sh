#!/bin/bash
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710
echo "===== CONFIG: SELINUX DEVEL / BOOTPARAM ====="
for f in $K/arch/arm64/configs/vendor/sdm670-perf_defconfig $K/arch/arm64/configs/sdm670-perf_defconfig $K/arch/arm64/configs/vendor/oplus/PBEM00.config; do
  echo "--- $(basename $f)"
  grep -E 'CONFIG_SECURITY_SELINUX|CONFIG_SECURITY_SELINUX_DEVELOP|CONFIG_SECURITY_SELINUX_BOOTPARAM|CONFIG_SECURITY_SELINUX_DISABLE' $f 2>/dev/null
done
echo
echo "===== out/.config (actual build) ====="
grep -E 'CONFIG_SECURITY_SELINUX' $K/out/.config 2>/dev/null | head -8
echo
echo "===== kernel: selinux=0 handling ====="
grep -rn 'selinux_enabled' $K/security/selinux/hooks.c 2>/dev/null | head -10
echo "--- bootparam code ---"
grep -n -A6 'selinux_enabled_setup\|__setup("selinux' $K/security/selinux/hooks.c | head -20
echo
echo "===== selinuxfs behavior when disabled ====="
grep -n -B2 -A8 'selinux_disabled\|selinux_initialized' $K/security/selinux/selinuxfs.c 2>/dev/null | head -40
