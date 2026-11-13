#!/bin/bash
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
R=/root/stage2
rm -rf $R; mkdir -p $R
dmesg -C 2>/dev/null
timeout -k 5 75 unshare -m -p -f --kill-child --propagation private bash -c '
  mount -o loop,ro '"$IMG"' '"$R"' || { echo MOUNTFAIL; exit 1; }
  mount -t tmpfs tmpfs '"$R"'/dev
  for n in "null c 1 3" "zero c 1 5" "urandom c 1 9" "random c 1 8" "kmsg c 1 11" "ptmx c 5 2"; do
    set -- $n; mknod '"$R"'/dev/$1 $2 $3 $4 2>/dev/null
  done
  mkdir -p '"$R"'/dev/socket '"$R"'/dev/pts
  mount -t proc proc '"$R"'/proc
  mount -t sysfs sysfs '"$R"'/sys
  mount -t selinuxfs selinuxfs '"$R"'/sys/fs/selinux 2>/dev/null
  exec chroot '"$R"' /system/bin/init second_stage
' > /tmp/stage2.log 2>&1
echo "rc=$?"
echo "===== init log (kmsg) ====="
dmesg 2>/dev/null | grep -a 'init:' | head -70
echo "===== stderr ====="
head -20 /tmp/stage2.log
echo DONE_STAGE2
