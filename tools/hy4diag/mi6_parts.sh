#!/bin/bash
PKG='/mnt/e/work/oppo-pbem00-kernel/小米6_HyperOS 4.0.30.0.XPCCNXM_pudding_一键刷入'
echo "===== all non-empty filename+label pairs ====="
grep -hoE 'filename="[^"]+" label="[^"]+"' $PKG/images/rawprogram*.xml | sort -u
echo
echo "===== vendor label row ====="
grep -h -oE '<program [^>]*label="vendor"[^>]*>' $PKG/images/rawprogram*.xml | head -3
echo
echo "===== cust label row ====="
grep -h -oE '<program [^>]*label="cust"[^>]*>' $PKG/images/rawprogram*.xml | head -3
echo
echo "===== HyperOS3 vendor.new.dat -> extract via sdat2img? ====="
echo "(transfer.list based; check tools availability)"
command -v python3 >/dev/null && echo python3 OK
unzip -l "$PKG/zip/HyperOS 3 W-OTA-8 simplified.zip" | grep -E 'vendor|product|odm|system'
