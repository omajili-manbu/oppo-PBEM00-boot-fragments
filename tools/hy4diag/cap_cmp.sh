#!/bin/bash
echo "########## mi6 ramdisk init: full first-stage capability list ##########"
MI=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag/mi6/rd/init
OU=/root/ib2/init
for f in $MI $OU; do
  echo "=== $(basename $f) : $(stat -c%s $f) bytes"
  strings -a $f | grep -aE 'first_stage_mount|first_stage_ramdisk|/system_root|switch_root|SwitchRoot|MS_MOVE|ReadFstabFromDt|mnt_point|need_dm_verity|avb=|slotselect|logical' | sort -u | head -14
  echo
done

echo "########## who calls SwitchRoot -> what mount point ##########"
for f in $MI $OU; do
  echo "=== $(basename $f)"
  strings -a $f | grep -aE '^/(system|system_root|newroot|first_stage_ramdisk)$' | head
  strings -a $f | grep -aE 'mount point|mnt_point|switching root|SwitchRoot' | head -6
done

echo
echo "########## compare: does mi6 init reference /system_root? ##########"
for f in $MI $OU; do
  printf '%-12s /system_root=%s  /newroot=%s  fstab.qcom=%s\n' "$(basename $f)" \
    "$(strings -a $f | grep -c '/system_root')" \
    "$(strings -a $f | grep -c '/newroot')" \
    "$(strings -a $f | grep -c 'fstab.qcom')"
done
echo DONE_CAP
