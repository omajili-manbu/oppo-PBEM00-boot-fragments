#!/bin/bash
cd /root
# SetupSelinux is at 0x11b0a4; disassemble the whole function generously
START=0x11b0a4
STOP=0x11c800
echo "########## SetupSelinux disassembly (patched site marked) ##########"
aarch64-linux-gnu-objdump -d --start-address=$START --stop-address=$STOP init_ours 2>/dev/null \
  | grep -E '^\s+[0-9a-f]+:' > /root/sel_ours.txt
aarch64-linux-gnu-objdump -d --start-address=$START --stop-address=$STOP init_mi6 2>/dev/null \
  | grep -E '^\s+[0-9a-f]+:' > /root/sel_mi6.txt
echo "lines ours=$(wc -l < /root/sel_ours.txt) mi6=$(wc -l < /root/sel_mi6.txt)"
echo
echo "########## the region around the patch (ours) ##########"
awk '$1 ~ /^11c7[0-9a-f]{2}:/ || $1 ~ /^11c76[0-9a-f]:/' /root/sel_ours.txt | head -20
echo
echo "########## find PLT stubs referenced near patch ##########"
for a in 29dc08 29f0a8 29fd38 29fd20; do
  echo "--- target $a ---"
  aarch64-linux-gnu-objdump -d init_ours 2>/dev/null | grep -E "^0*$a <" | head -2
done
echo
echo "########## dynamic symbols: resolve those PLT entries ##########"
aarch64-linux-gnu-readelf -rW init_ours 2>/dev/null | awk '$1 ~ /^0*29d/ || $1 ~ /^0*29f/' | head -20
echo
echo "########## all LOG(FATAL)-ish strings mentioning selinux ##########"
strings -a -t x init_ours | grep -aiE 'selinux' | head -30
echo DONE_SEL
