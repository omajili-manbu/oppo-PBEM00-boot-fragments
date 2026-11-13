#!/bin/bash
M1=/mnt/mi6s; M2=/mnt/ours
mountpoint -q $M1 || mount -o loop,ro /mnt/e/hy4tmp/system.raw $M1
mountpoint -q $M2 || mount -o loop,ro /mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img $M2
cp $M1/system/bin/init /root/init_mi6
cp $M2/system/bin/init /root/init_ours
echo "===== byte diffs (cmp -l) ====="
cmp -l /root/init_ours /root/init_mi6 | head -40
echo "diff bytes total: $(cmp -l /root/init_ours /root/init_mi6 | wc -l)"
echo "===== sections ====="
readelf -S /root/init_ours | grep -E 'text|rodata|data' | head -6
echo "===== kernel class sanity check ====="
K=/root/cip.Image
for c in chr_file property_service unix_stream_socket bpf io_uring perf_event; do
  echo "  $c: $(strings -a $K | grep -cx "$c")"
done
echo DONE_DIFF
