#!/bin/bash
PKG='/mnt/e/work/oppo-pbem00-kernel/小米6_HyperOS 4.0.30.0.XPCCNXM_pudding_一键刷入'
T=/mnt/e/hy4tmp
mkdir -p $T
echo "===== rawprogram: where system.img goes ====="
grep -hoE 'filename="system.img"[^/]*' $PKG/images/rawprogram*.xml | head -3
grep -hoE 'label="system"[^/]*' $PKG/images/rawprogram*.xml | head -3
echo "===== convert cust.img (400M) ====="
rm -f $T/cust.raw
simg2img $PKG/images/cust.img $T/cust.raw && echo CUST_RAW_OK
ls -l $T/cust.raw
rm -rf /mnt/custm && mkdir -p /mnt/custm
mount -o loop,ro $T/cust.raw /mnt/custm && echo CUST_MOUNT_OK
echo "--- cust root ---"; ls /mnt/custm | head
echo "--- cust selinux ---"; ls /mnt/custm/etc/selinux/ 2>/dev/null | head -20
echo "--- cust plat_sepolicy_vers ---"; cat /mnt/custm/etc/selinux/plat_sepolicy_vers.txt 2>/dev/null
echo "--- cust build.prop (if any) ---"; grep -hE 'ro.build.version.(sdk|release)|ro.vndk.version' /mnt/custm/build.prop 2>/dev/null | head
umount /mnt/custm 2>/dev/null
echo "===== kick off system.img conversion in background ====="
rm -f $T/system.raw
nohup bash -c "simg2img '$PKG/images/system.img' $T/system.raw && echo SYS_RAW_DONE > $T/sys.done" > $T/sys.log 2>&1 &
sleep 2
echo "started pid $!"
df -h /mnt/e | tail -1
echo DONE_CUST
