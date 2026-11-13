#!/bin/bash
set -e
PKG='/mnt/e/work/oppo-pbem00-kernel/小米6_HyperOS 4.0.30.0.XPCCNXM_pudding_一键刷入'
W=/root/mi6dtb
rm -rf $W && mkdir -p $W && cd $W

echo "=== extract Image + appended DTB from cip106 Image.gz-dtb ==="
cp "$PKG/zip/cip106 5.10bpf ext4.zip" /root/cip.zip
unzip -o -q /root/cip.zip Image.gz-dtb -d $W
ls -l $W/Image.gz-dtb

python3 - <<'PY'
import gzip, zlib, sys
p='/root/mi6dtb/Image.gz-dtb'
raw=open(p,'rb').read()
# try gzip first
try:
    data = gzip.decompress(raw)
    print('gzip decompressed:', len(data))
except Exception as e:
    print('gzip failed:', e)
    data = raw
open('/root/mi6dtb/Image.bin','wb').write(data)
# find all DTB magic points
magic=b'\xd0\x0d\xfe\xed'
offs=[]
i=0
while True:
    j=data.find(magic,i)
    if j<0: break
    offs.append(j); i=j+1
print('DTB magic offsets:', offs[:10], 'count', len(offs))
if offs:
    # last one is usually the appended dtb
    o=offs[-1]
    import struct
    total=struct.unpack('>I', data[o+4:o+8])[0]
    print('dtb total_size', total)
    open('/root/mi6dtb/kernel_dtb','wb').write(data[o:o+total])
    print('wrote kernel_dtb', total)
PY

echo "=== decompile their ACTUAL dtb ==="
if [ -f $W/kernel_dtb ]; then
  dtc -I dtb -O dts $W/kernel_dtb 2>/dev/null > $W/mi6_real.dts
  echo "dts lines: $(wc -l < $W/mi6_real.dts)"
  echo "--- android,fstab ---"
  sed -n '/fstab {/,/^			};/p' $W/mi6_real.dts | head -40
  echo "--- grep mnt_point ---"
  grep -n 'mnt_point' $W/mi6_real.dts | head -10
  echo "--- chosen/bootargs ---"
  grep -n -A4 'chosen {' $W/mi6_real.dts | head -8
fi
echo DONE
