#!/bin/bash
D=/mnt/e/work/oppo-pbem00-kernel/tools/hy4diag/mi6
command -v dtc >/dev/null 2>&1 || DEBIAN_FRONTEND=noninteractive apt-get install -y device-tree-compiler >/dev/null 2>&1
echo "===== base kernel (boot.img) ====="
zcat $D/kernel 2>/dev/null | strings -a | grep -m2 'Linux version'
echo "===== DTB fstab nodes ====="
dtc -I dtb -O dts $D/kernel_dtb 2>/dev/null > /tmp/mi6.dts
echo "dts lines: $(wc -l < /tmp/mi6.dts)"
grep -n -i -A8 'fstab' /tmp/mi6.dts | head -60
echo "===== DTB: by-name / system refs ====="
grep -n -iE 'by-name|/system|system ' /tmp/mi6.dts | head -20

echo "===== cip106 kernel: SELinux class support ====="
cd /root/pk/c 2>/dev/null || exit 1
(zcat Image.gz-dtb 2>/dev/null || cat Image.gz-dtb) > /root/cip.Image
strings -a /root/cip.Image | grep -m2 'Linux version'
for c in io_uring perf_event process2 memfd_file user_namespace lockdown xdp_socket bpf mctp_socket vsock_socket smc_socket; do
  n=$(strings -a /root/cip.Image | grep -cx "$c")
  echo "  class $c: $n"
done
echo "--- policy version hints ---"
strings -a /root/cip.Image | grep -iE 'version range|policydb version|SELinux:  policydb' | head -5
echo DONE_MI6
