#!/bin/bash
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
K=/mnt/e/play/MIO-KITCHEN/r17HyperOS4
R=/root/stage2

# policies (reuse if already extracted)
if [ ! -d /root/pol/vendor ] || [ -z "$(ls -A /root/pol/vendor 2>/dev/null)" ]; then
  rm -rf /root/pol && mkdir -p /root/pol
  for p in vendor product odm; do
    mkdir -p /root/m_$p /root/pol/$p
    erofsfuse $K/$p.img /root/m_$p 2>/dev/null; sleep 1
    [ -d /root/m_$p/etc/selinux ] && cp -a /root/m_$p/etc/selinux/. /root/pol/$p/ 2>/dev/null
    fusermount -u /root/m_$p 2>/dev/null
  done
fi
echo "pol: vendor=$(ls /root/pol/vendor | wc -l) product=$(ls /root/pol/product | wc -l) odm=$(ls /root/pol/odm | wc -l)"
echo "--- vendor plat_sepolicy_vers ---"; cat /root/pol/vendor/plat_sepolicy_vers.txt 2>/dev/null

rm -rf $R; mkdir -p $R
dmesg -C 2>/dev/null
timeout -k 5 90 unshare -m -p -f --kill-child --propagation private bash -c '
  mount -o loop,ro '"$IMG"' '"$R"' || { echo MOUNTFAIL; exit 1; }
  for p in vendor product odm; do
    mount -t tmpfs tmpfs '"$R"'/$p
    mkdir -p '"$R"'/$p/etc/selinux
    cp -a /root/pol/$p/. '"$R"'/$p/etc/selinux/ 2>/dev/null
  done
  mount -t tmpfs tmpfs '"$R"'/dev
  for n in "null c 1 3" "zero c 1 5" "urandom c 1 9" "random c 1 8" "kmsg c 1 11" "ptmx c 5 2"; do
    set -- $n; mknod '"$R"'/dev/$1 $2 $3 $4 2>/dev/null
  done
  mkdir -p '"$R"'/dev/socket '"$R"'/dev/pts
  mount -t proc proc '"$R"'/proc
  mount -t sysfs sysfs '"$R"'/sys
  mount -t selinuxfs selinuxfs '"$R"'/sys/fs/selinux 2>/dev/null
  exec chroot '"$R"' /system/bin/init second_stage
' > /tmp/stage2c.log 2>&1
echo "rc=$?"
echo "===== init log (kmsg) ====="
dmesg 2>/dev/null | grep -aE 'init:|SELinux|selinux|avc|policy' | head -60
echo "===== stderr ====="
head -10 /tmp/stage2c.log
echo DONE_STAGE2C
