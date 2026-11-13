#!/bin/bash
RAW=/mnt/e/hy4tmp/system.raw
OURS=/mnt/e/play/MIO-KITCHEN/r17HyperOS4/system_merged.img
M1=/mnt/mi6s; M2=/mnt/ours
mkdir -p $M1 $M2
mountpoint -q $M1 || mount -o loop,ro $RAW $M1
mountpoint -q $M2 || mount -o loop,ro $OURS $M2
echo "mounted: mi6=$(mountpoint -q $M1 && echo yes) ours=$(mountpoint -q $M2 && echo yes)"
echo "===== root (mi6) ====="
ls $M1 | tr '\n' ' '; echo
echo "===== init compare ====="
ls -l $M1/system/bin/init $M2/system/bin/init 2>&1
sha256sum $M1/system/bin/init $M2/system/bin/init 2>/dev/null | cut -c1-24
echo "===== interp / needed ====="
readelf -l $M1/system/bin/init 2>/dev/null | grep -i 'interp' | head -2
readelf -d $M1/system/bin/init 2>/dev/null | grep -c NEEDED
readelf -l $M2/system/bin/init 2>/dev/null | grep -i 'interp' | head -2
readelf -d $M2/system/bin/init 2>/dev/null | grep -c NEEDED
echo "===== policy-load strings ====="
for s in 'Loading SELinux policy' 'Failed to load SELinux policy' 'Unable to load SELinux policy' 'SelinuxInitialize' 'plat_sepolicy_vers' 'SELinux is disabled'; do
  a=$(strings -a $M1/system/bin/init 2>/dev/null | grep -cF "$s")
  b=$(strings -a $M2/system/bin/init 2>/dev/null | grep -cF "$s")
  printf '  %-38s mi6=%s ours=%s\n' "$s" "$a" "$b"
done
echo "===== their vendor / apex ====="
echo "vendor entries: $(ls -A $M1/vendor 2>/dev/null | wc -l)"
echo "system/apex: $(ls -A $M1/system/apex 2>/dev/null | wc -l)"
echo "bootstrap-apex: $(ls -A $M1/bootstrap-apex 2>/dev/null | wc -l)"
echo "cust dir in image: $(ls -A $M1/cust 2>/dev/null | wc -l)"
echo "===== their selinux sets ====="
echo "system/etc/selinux: $(ls -A $M1/system/etc/selinux 2>/dev/null | wc -l)"
echo "system_ext: $(ls -A $M1/system_ext/etc/selinux 2>/dev/null | wc -l)"
echo "mi_ext: $(ls -A $M1/mi_ext/etc/selinux 2>/dev/null | wc -l)"
echo "===== md5 of plat_sepolicy.cil (mi6 vs ours) ====="
md5sum $M1/system/etc/selinux/plat_sepolicy.cil $M2/system/etc/selinux/plat_sepolicy.cil 2>/dev/null
echo DONE_CMP
