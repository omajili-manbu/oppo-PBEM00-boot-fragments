#!/bin/bash
IMG=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
K=/mnt/e/play/MIO-KITCHEN/r17HyperOS4
R=/root/stage2; U=/root/ovl_up; W=/root/ovl_wk; O=/root/ovl_mnt

echo "=== extract selinux dirs from vendor/product/odm ==="
rm -rf /root/pol && mkdir -p /root/pol
for p in vendor product odm; do
  mkdir -p /root/m_$p /root/pol/$p
  erofsfuse $K/$p.img /root/m_$p 2>/dev/null
  sleep 1
  if [ -d /root/m_$p/etc/selinux ]; then
    cp -a /root/m_$p/etc/selinux/. /root/pol/$p/ 2>/dev/null
    echo "$p: $(ls /root/pol/$p | wc -l) files"
    ls /root/pol/$p | head -6
  else
    echo "$p: NO etc/selinux"
  fi
  fusermount -u /root/m_$p 2>/dev/null
done

echo "=== run second_stage with policies in place ==="
rm -rf $R $U $W $O; mkdir -p $R $U $W $O
dmesg -C 2>/dev/null
timeout -k 5 90 unshare -m -p -f --kill-child --propagation private bash -c '
  mount -o loop,ro '"$IMG"' '"$R"' || { echo MOUNTFAIL; exit 1; }
  mount -t tmpfs tmpfs '"$U"'
  mount -t overlay overlay -o lowerdir='"$R"',upperdir='"$U"',workdir='"$W"' '"$O"' || { echo OVLFAIL; exit 1; }
  for p in vendor product odm; do mkdir -p '"$O"'/$p/etc/selinux; cp -a /root/pol/$p/. '"$O"'/$p/etc/selinux/ 2>/dev/null; done
  echo "vendor policy files: $(ls '"$O"'/vendor/etc/selinux | wc -l)"
  mount -t tmpfs tmpfs '"$O"'/dev
  for n in "null c 1 3" "zero c 1 5" "urandom c 1 9" "random c 1 8" "kmsg c 1 11" "ptmx c 5 2"; do
    set -- $n; mknod '"$O"'/dev/$1 $2 $3 $4 2>/dev/null
  done
  mkdir -p '"$O"'/dev/socket '"$O"'/dev/pts
  mount -t proc proc '"$O"'/proc
  mount -t sysfs sysfs '"$O"'/sys
  mount -t selinuxfs selinuxfs '"$O"'/sys/fs/selinux 2>/dev/null
  exec chroot '"$O"' /system/bin/init second_stage
' > /tmp/stage2b.log 2>&1
echo "rc=$?"
echo "===== init log (kmsg) ====="
dmesg 2>/dev/null | grep -aE 'init:|SELinux|selinux|avc' | head -50
echo "===== stderr ====="
head -10 /tmp/stage2b.log
echo DONE_STAGE2B
