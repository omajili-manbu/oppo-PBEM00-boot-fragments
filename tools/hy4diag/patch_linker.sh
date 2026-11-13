#!/bin/bash
set -e
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
M=/mnt/ours

echo "=== mount rw ==="
mkdir -p $M
mountpoint -q $M || mount -o loop,rw $IMG $M || true
mountpoint -q $M && echo "mounted rw"

L=$M/system/bin/bootstrap/linker64
echo "=== before: instruction at 0xf6b34 ==="
od -A x -t x1 -j $((0xf6b30)) -N 8 "$L"

# b.eq f6bf0 at 0xf6b34  (0x540005e0)  ->  nop (0xd503201f)
printf '\x1f\x20\x03\xd5' | dd of="$L" bs=1 seek=$((0xf6b34)) conv=notrunc status=none

echo "=== after ==="
od -A x -t x1 -j $((0xf6b30)) -N 8 "$L"

echo "=== verify by disassembly ==="
cp "$L" /root/linker64_patched
aarch64-linux-gnu-objdump -d --start-address=0xf6b20 --stop-address=0xf6b40 /root/linker64_patched 2>/dev/null | tail -n +7

echo "=== sync + fsck ==="
sync
cd /; umount $M
e2fsck -f -n $IMG 2>&1 | tail -3
sha256sum $IMG | cut -c1-24
echo PATCHED_LINKER_OK
