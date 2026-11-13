#!/bin/bash
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710
cd $K
echo "=== System.map location ==="
ls -l out/System.map 2>/dev/null || find . -maxdepth 3 -name 'System.map' 2>/dev/null | head -3

echo
echo "=== symbols ==="
for s in copy_one_pte madvise_behavior do_madvise SyS_madvise; do
  printf '  %-18s %s\n' "$s" "$(grep -m1 -E " $s\$" out/System.map 2>/dev/null)"
done

echo
echo "=== nm on vmlinux ==="
aarch64-linux-gnu-nm -n out/vmlinux 2>/dev/null | grep -E ' (copy_one_pte|madvise_behavior|do_madvise)$' | head -5

echo
echo "=== disasm madvise_behavior: look for 0x12/0x13 comparisons ==="
A=$(aarch64-linux-gnu-nm -n out/vmlinux 2>/dev/null | awk '$3=="madvise_behavior"{print $1; exit}')
echo "addr=$A"
if [ -n "$A" ]; then
  aarch64-linux-gnu-objdump -d --start-address=0x$A --stop-address=$((0x$A + 0x500)) out/vmlinux 2>/dev/null \
    | grep -E 'cmp\s+w[0-9]+, #0x1[0-9]|mov\s+w[0-9]+, #0x1[0-9]' | head -10
fi

echo
echo "=== disasm copy_one_pte: look for bit-23 test (0x800000) ==="
B=$(aarch64-linux-gnu-nm -n out/vmlinux 2>/dev/null | awk '$3=="copy_one_pte"{print $1; exit}')
echo "addr=$B"
if [ -n "$B" ]; then
  aarch64-linux-gnu-objdump -d --start-address=0x$B --stop-address=$((0x$B + 0x100)) out/vmlinux 2>/dev/null \
    | grep -E 'tbn?z?\s+w[0-9]+, #23|#0x800000' | head -5
  echo "--- first 12 insns ---"
  aarch64-linux-gnu-objdump -d --start-address=0x$B --stop-address=$((0x$B + 0x40)) out/vmlinux 2>/dev/null | tail -n +7 | head -12
fi
echo DONE_VERIFY
