#!/bin/bash
PKG='/mnt/e/work/oppo-pbem00-kernel/小米6_HyperOS 4.0.30.0.XPCCNXM_pudding_一键刷入'
C=/mnt/c/hy4work
mkdir -p $C

echo "===== rawprogram: filename+label pairs ====="
grep -hoE 'filename="[^"]+" label="[^"]+"' "$PKG"/images/rawprogram*.xml | sort -u | head -30

echo
echo "===== vendor row detail ====="
grep -h -oE '<program [^>]*label="vendor"[^>]*>' "$PKG"/images/rawprogram*.xml | head -2
echo
echo "===== cust row detail ====="
grep -h -oE '<program [^>]*label="cust"[^>]*>' "$PKG"/images/rawprogram*.xml | head -2

echo
echo "===== extract vendor.new.dat + transfer.list ====="
cd "$C"
unzip -o -q "$PKG/zip/HyperOS 3 W-OTA-8 simplified.zip" vendor.new.dat vendor.transfer.list vendor.patch.dat -d "$C/ota"
ls -l "$C/ota"
