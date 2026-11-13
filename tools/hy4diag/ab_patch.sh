#!/bin/bash
M=/mnt/ours
mountpoint -q $M || mount -o loop,ro /mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img $M
cp $M/system/bin/init /root/init_patched
printf '\x00' | dd of=/root/init_patched bs=1 seek=$((0x11C76C)) conv=notrunc status=none
echo "patch applied: $(cmp -l $M/system/bin/init /root/init_patched | head -2)"
chmod 0755 /root/init_patched

run_case() {
  local name="$1" initfile="$2" arg="$3"
  echo "########## CASE $name (init=$(basename $initfile), arg=$arg) ##########"
  dmesg -C 2>/dev/null
  timeout -k 5 60 unshare -m -p -f --kill-child --propagation private bash -c '
    R=/mnt/run_'"$name"'
    rm -rf $R; mkdir -p $R
    mount -o loop,ro /mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img $R
    mount --bind '"$initfile"' $R/system/bin/init
    for p in vendor product odm; do mount -t tmpfs tmpfs $R/$p; mkdir -p $R/$p/etc/selinux; cp -a /root/pol/$p/. $R/$p/etc/selinux/ 2>/dev/null; done
    mount -t tmpfs tmpfs $R/dev
    for n in "null c 1 3" "zero c 1 5" "urandom c 1 9" "random c 1 8" "kmsg c 1 11" "ptmx c 5 2" "console c 5 1"; do set -- $n; mknod $R/dev/$1 $2 $3 $4 2>/dev/null; done
    mkdir -p $R/dev/socket $R/dev/pts; mount -t devpts devpts $R/dev/pts 2>/dev/null
    mount -t proc proc $R/proc
    mount -t sysfs sysfs $R/sys
    mount -t selinuxfs selinuxfs $R/sys/fs/selinux 2>/dev/null
    mkdir -p $R/apex $R/bootstrap-apex $R/linkerconfig
    exec chroot $R /system/bin/init '"$arg"'
  ' > /tmp/case_$name.log 2>&1
  echo "rc=$?"
  dmesg 2>/dev/null | grep -aE 'init:|SELinux|selinux' | head -25
  echo "--- stderr ---"; head -8 /tmp/case_$name.log
}

run_case A_unpatched $M/system/bin/init selinux_setup
run_case B_patched  /root/init_patched selinux_setup
echo DONE_AB
