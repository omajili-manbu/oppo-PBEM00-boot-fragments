#!/bin/bash
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
MI=$D/mi6/rd/init
OU=/root/ib2/init

echo "########## sizes ##########"
ls -l $MI $OU 2>&1

echo "########## static init: who logs how? ##########"
for f in $MI $OU; do
  echo "--- $f"
  for s in 'init first stage started' 'init first stage completed' 'switch_root' 'SetupDevMounts' 'devtmpfs' 'Could not set up /dev' 'execv(' 'selinux_setup' 'second_stage' 'force_normal_boot' 'skip_initramfs' 'mnt_point' 'fstab.'; do
    printf '    %-32s %s\n' "$s" "$(strings -a $f | grep -cF "$s")"
  done
done

echo "########## version markers ##########"
for f in $MI $OU; do
  echo "--- $f"
  strings -a $f | grep -aE 'Android [0-9]+|r[0-9]{2,}|based on r' | head -3
  strings -a $f | grep -aE '^[0-9]{6,}$' | head -3
done

echo "########## their kernel: devtmpfs / pidns / sysvipc ##########"
K=/root/cip.Image
for s in devtmpfs 'devtmpfs: initialized' 'pid_namespaces' MADV_WIPEONFORK; do
  echo "  $s: $(strings -a $K | grep -cF "$s")"
done
echo "  kernel version: $(strings -a $K | grep -m1 'Linux version')"

echo "########## our 4.9 kernel config: devtmpfs/pidns ##########"
CFG=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710/arch/arm64/configs/vendor/oplus/PBEM00.config
grep -E 'DEVTMPFS|PID_NS|SYSVIPC|TMPFS|MEMFD|USERFAULTFD' $CFG 2>/dev/null || echo "  (not in PBEM00.config)"
D2=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710/arch/arm64/configs/vendor/sdm670-perf_defconfig
echo "--- sdm670-perf_defconfig ---"
grep -E 'CONFIG_DEVTMPFS|CONFIG_PID_NS|CONFIG_SYSVIPC|CONFIG_TMPFS' $D2 2>/dev/null || echo "  (none)"
echo DONE
