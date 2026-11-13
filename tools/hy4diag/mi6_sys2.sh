#!/bin/bash
P='/mnt/e/work/oppo-pbem00-kernel/小米6_HyperOS 4.0.30.0.XPCCNXM_pudding_一键刷入/images'
T=/mnt/e/hy4tmp
mkdir -p $T
echo "===== cust.img -> raw ====="
rm -f "$T/cust.raw"
simg2img "$P/cust.img" "$T/cust.raw" && echo CUST_OK
ls -l "$T/cust.raw" 2>/dev/null
rm -rf /mnt/custm; mkdir -p /mnt/custm
if mount -o loop,ro "$T/cust.raw" /mnt/custm; then
  echo "--- cust root ---"; ls /mnt/custm | head -12
  echo "--- cust/etc/selinux ---"; ls /mnt/custm/etc/selinux/ 2>/dev/null | head -20
  echo "--- plat_sepolicy_vers ---"; cat /mnt/custm/etc/selinux/plat_sepolicy_vers.txt 2>/dev/null
  echo "--- cust build.prop ---"; grep -hE 'ro.build.version.(sdk|release)|ro.vndk.version|ro.product.device' /mnt/custm/build.prop 2>/dev/null | head -6
  umount /mnt/custm
fi
echo "===== system.img -> raw (background) ====="
rm -f "$T/system.raw" "$T/sys.done"
nohup bash -c "simg2img '$P/system.img' '$T/system.raw' && echo SYS_RAW_DONE > '$T/sys.done'" > "$T/sys.log" 2>&1 &
echo "bg pid=$!"
df -h /mnt/e | tail -1
echo DONE_STEP
