#!/bin/bash
set -e
V='/mnt/c/Users/QWE12/Desktop/vendor_A17fix.img'
M=/mnt/vfix
mkdir -p $M
mountpoint -q $M || mount -o loop,rw "$V" $M
echo "mounted: $(mountpoint -q $M && echo yes)"
ls -l $M/etc/fstab.qcom
cp -f $M/etc/fstab.qcom $M/etc/fstab.qcom.a10bak
cat > $M/etc/fstab.qcom <<'FSTAB_EOF'
# Android fstab file (PBEM00: A10 vendor + A17 system bring-up, A17-compatible syntax)
#<src>                                                  <mnt_point>              <type>  <mnt_flags and options>                                                   <fs_mgr_flags>
/dev/block/bootdevice/by-name/userdata                   /data                    ext4    noatime,nosuid,nodev,barrier=1,noauto_da_alloc,async_discard              latemount,wait,check,formattable
/dev/block/bootdevice/by-name/cache                      /cache                   ext4    nosuid,noatime,nodev,barrier=1,async_discard                             wait,check
/dev/block/bootdevice/by-name/modem                      /vendor/firmware_mnt     vfat    ro,shortname=lower,uid=1000,gid=1000,dmask=227,fmask=337,context=u:object_r:firmware_file:s0 wait
/dev/block/bootdevice/by-name/dsp                        /vendor/dsp              ext4    ro,nosuid,nodev,barrier=1,async_discard                                   wait
/dev/block/bootdevice/by-name/persist                    /mnt/vendor/persist      ext4    nosuid,noatime,nodev,barrier=1,async_discard                               wait
/devices/platform/soc/8804000.sdhci/mmc_host*            /storage/sdcard1         vfat    nosuid,nodev                                                              wait,voldmanaged=sdcard1:auto
/devices/platform/soc/1da4000.ufshc_card/host*           /storage/sdcard1         vfat    nosuid,nodev                                                              wait,voldmanaged=sdcard1:auto
FSTAB_EOF
chmod 0644 $M/etc/fstab.qcom
sync
echo "--- new fstab ---"
cat $M/etc/fstab.qcom
echo "--- sizes ---"
ls -l $M/etc/fstab.qcom $M/etc/fstab.qcom.a10bak
