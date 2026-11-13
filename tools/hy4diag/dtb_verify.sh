#!/bin/bash
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710
DTB=$K/out/arch/arm64/boot/dts/18081/sdm670.dtb
echo "########## 1. new DTB fstab ##########"
dtc -I dtb -O dts "$DTB" 2>/dev/null > /root/new.dts
sed -n '/fstab {/,/^			};/p' /root/new.dts | head -30
echo "--- checks ---"
for p in 'android,fstab' 'android,system' 'by-name/system' 'android,vendor'; do
  printf '  %-20s %s\n' "$p" "$(grep -cF "$p" /root/new.dts)"
done
echo "--- size ---"; ls -l "$DTB"

echo
echo "########## 2. resolve PLT symbols used in SetupSelinux ##########"
cd /root
for a in 29dc08 29dcc8 29fd20 29fd38 29f0a8 29dc08; do
  echo "--- 0x$a ---"
  # find which .rela.plt entry has r_offset == a
  aarch64-linux-gnu-readelf -rW init_ours 2>/dev/null | grep -i "0*$a " | head -2
done
echo
echo "--- all rela.plt around those addresses ---"
aarch64-linux-gnu-readelf -rW init_ours 2>/dev/null | awk 'strtonum("0x"$1) >= 0x29d000 && strtonum("0x"$1) <= 0x2a0000 {print}' | head -40
echo DONE
