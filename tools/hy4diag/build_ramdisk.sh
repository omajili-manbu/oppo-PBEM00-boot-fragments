#!/bin/bash
set -e
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag
R=/root/ramdisk
OUT=$D/bootbuild

echo "=== toolchain ==="
command -v aarch64-linux-gnu-gcc >/dev/null 2>&1 || DEBIAN_FRONTEND=noninteractive apt-get install -y gcc-aarch64-linux-gnu >/dev/null 2>&1
aarch64-linux-gnu-gcc --version | head -1

echo "=== policies (re-extract if missing) ==="
if [ ! -d /root/pol/vendor ] || [ -z "$(ls -A /root/pol/vendor 2>/dev/null)" ]; then
  rm -rf /root/pol && mkdir -p /root/pol
  for p in vendor product odm; do
    mkdir -p /root/m_$p /root/pol/$p
    erofsfuse /mnt/e/play/MIO-KITCHEN/r17HyperOS4/$p.img /root/m_$p 2>/dev/null; sleep 1
    [ -d /root/m_$p/etc/selinux ] && cp -a /root/m_$p/etc/selinux/. /root/pol/$p/ 2>/dev/null
    fusermount -u /root/m_$p 2>/dev/null
  done
fi
echo "pol files: $(find /root/pol -type f | wc -l)"

echo "=== build static shim ==="
aarch64-linux-gnu-gcc -static -O2 -o /root/shim $D/shim.c
file /root/shim; ls -l /root/shim

echo "=== assemble ramdisk ==="
rm -rf $R && mkdir -p $R && cd $R
cpio -idm --no-absolute-filenames < $D/ib/ramdisk.cpio 2>/dev/null
rm -f init
cp /root/shim init && chmod 0750 init
mkdir -p pol/vendor pol/product pol/odm newroot
cp -a /root/pol/vendor/.  pol/vendor/
cp -a /root/pol/product/. pol/product/
cp -a /root/pol/odm/.     pol/odm/
echo "--- ramdisk tree ---"; find . -maxdepth 3 | head -30
echo "--- sizes ---"; du -sh . ; echo "pol files: $(find pol -type f | wc -l)"

echo "=== pack cpio (newc) ==="
find . -print0 | cpio --null -o -H newc --owner=0:0 > $D/ramdisk_hy4.cpio 2>/dev/null
ls -l $D/ramdisk_hy4.cpio

echo "=== stage boot components ==="
rm -rf $OUT && mkdir -p $OUT
cp $D/b1/kernel $OUT/kernel
cp $D/b1/kernel_dtb $OUT/kernel_dtb
cp $D/b1/header $OUT/header
cp $D/ramdisk_hy4.cpio $OUT/ramdisk.cpio
ls -la $OUT
echo READY_FOR_REPACK
