#!/bin/bash
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img

echo "########## 1. verify repacked boot.img ##########"
rm -rf /root/vb && mkdir -p /root/vb && cd /root/vb
cp $D/bootbuild/boot_hy4_test.img .
/e/play/MIO-KITCHEN/bin/Windows/AMD64/magiskboot.exe unpack -h boot_hy4_test.img >/dev/null 2>&1
echo "--- cmdline ---"; grep '^cmdline=' header
echo "--- kernel sha (orig vs new) ---"
sha256sum kernel | cut -c1-24; sha256sum $D/b1/kernel | cut -c1-24
echo "--- ramdisk /init ---"
rm -rf /root/rdv && mkdir -p /root/rdv && cd /root/rdv
cp /root/vb/ramdisk.cpio . && cpio -idm --no-absolute-filenames < ramdisk.cpio 2>/dev/null
ls -l init; file init
echo "--- /pol present ---"; ls pol; find pol -type f | wc -l

echo "########## 2. sandbox end-to-end shim test ##########"
sed 's|/dev/block/platform/soc/1d84000.ufshc/by-name/system|/dev/loop0|' $D/shim.c > /root/shim_test.c
aarch64-linux-gnu-gcc -static -O2 -o /root/shim_test /root/shim_test.c
R=/root/ramtest; rm -rf $R; mkdir -p $R; cd $R
cpio -idm --no-absolute-filenames < /root/rdv/ramdisk.cpio 2>/dev/null
rm -f init; cp /root/shim_test init; chmod 0750 init
for l in $(losetup -a | grep -F "$IMG" | cut -d: -f1); do losetup -d $l; done
LOOP=$(losetup -f --show -r $IMG); echo "LOOP=$LOOP"
dmesg -C 2>/dev/null
timeout -k 5 60 unshare -m -p -f --kill-child --propagation private bash -c '
  exec chroot '"$R"' /init
' > /tmp/shimtest.log 2>&1
echo "rc=$?"
echo "--- shim/init log (kmsg) ---"
dmesg 2>/dev/null | grep -aE 'hy4shim|init:|selinux' | head -30
echo "--- stderr ---"; head -10 /tmp/shimtest.log
losetup -d $LOOP 2>/dev/null
echo DONE_VERIFY
