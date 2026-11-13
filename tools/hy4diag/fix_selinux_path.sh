#!/bin/bash
set -e
SYS=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
VEN='/mnt/c/Users/QWE12/Desktop/vendor_A17fix.img'
MS=/mnt/sys
MV=/mnt/vfix

echo "=== A. vendor: swap /etc/selinux -> HyperOS (202504) ==="
mkdir -p $MV
mountpoint -q $MV || mount -o loop,rw "$VEN" $MV
if [ ! -d $MV/etc/selinux_a10bak ]; then
  mv $MV/etc/selinux $MV/etc/selinux_a10bak
else
  rm -rf $MV/etc/selinux
fi
mkdir -p $MV/etc/selinux
cp -a /root/pol/vendor/. $MV/etc/selinux/
echo "  vendored policy files: $(ls $MV/etc/selinux | wc -l)"
echo "  vers: $(cat $MV/etc/selinux/plat_sepolicy_vers.txt 2>/dev/null)"
ls $MV/etc/selinux | tr '\n' ' '; echo
sync
cd /; umount $MV
e2fsck -f -n "$VEN" 2>&1 | tail -2

echo
echo "=== B. system: patch libselinux security_load_policy -> return 0 ==="
mkdir -p $MS
mountpoint -q $MS || mount -o loop,rw $SYS $MS || true
L=$MS/system/lib64/libselinux.so
echo "--- before @0x12fc4 ---"
od -A x -t x4 -j $((0x12fc4)) -N 8 "$L"
# mov w0,#0 (0x52800000) ; ret (0xd65f03c0)
printf '\x00\x00\x80\x52\xc0\x03\x5f\xd6' | dd of="$L" bs=1 seek=$((0x12fc4)) conv=notrunc status=none
echo "--- after ---"
od -A x -t x4 -j $((0x12fc4)) -N 8 "$L"
cp "$L" /root/libselinux_patched
echo "--- disasm verify ---"
aarch64-linux-gnu-objdump -d --start-address=0x12fc4 --stop-address=0x12fe0 /root/libselinux_patched 2>/dev/null | tail -n +7
sync
cd /; umount $MS
e2fsck -f -n $SYS 2>&1 | tail -2
echo "system sha: $(sha256sum $SYS | cut -c1-24)"
echo "vendor sha: $(sha256sum "$VEN" | cut -c1-24)"
echo DONE_AB
