#!/bin/bash
cd /root
ADDR=0x11C78D
START=$(printf '0x%x' $((ADDR - 0x40)))
STOP=$(printf '0x%x' $((ADDR + 0x40)))
echo "===== ours around $ADDR ====="
aarch64-linux-gnu-objdump -d --start-address=$START --stop-address=$STOP init_ours 2>/dev/null | tail -n +7
echo "===== mi6 around $ADDR (patched) ====="
aarch64-linux-gnu-objdump -d --start-address=$START --stop-address=$STOP init_mi6 2>/dev/null | tail -n +7

echo "===== symbol via .gnu_debugdata ====="
for f in init_ours init_mi6; do
  aarch64-linux-gnu-objcopy --dump-section .gnu_debugdata=/root/$f.xz $f 2>/dev/null
  if [ -s /root/$f.xz ]; then
    xz -dc /root/$f.xz > /root/$f.sym 2>/dev/null
    echo "--- $f: nearest symbols to $ADDR ---"
    aarch64-linux-gnu-readelf -sW /root/$f.sym 2>/dev/null | awk -v a=$((ADDR)) '
      $4=="FUNC" { addr=strtonum("0x"$2); if (addr<=a) {best=$8; ba=addr} }
      END { printf "  %s @ 0x%x (delta 0x%x)\n", best, ba, a-ba }'
  else
    echo "  $f: no .gnu_debugdata"
  fi
done

echo "===== kernel SELinux presence ====="
for s in 'SELinux:' 'avc:' 'security_load_policy' 'property_service' 'selinux'; do
  echo "  mi6-kernel '$s': $(strings -a /root/cip.Image | grep -cF "$s")"
done
echo "===== our kernel (4.9) sanity ====="
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710
echo "  our kernel source has property_service: $(grep -c property_service $K/security/selinux/include/classmap.h 2>/dev/null)"
echo DONE_REV
