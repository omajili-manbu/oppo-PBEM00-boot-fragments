#!/bin/bash
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710
echo "===== BPF prog types in this tree ====="
grep -oE 'BPF_PROG_TYPE_[A-Z_0-9]+' $K/include/uapi/linux/bpf.h 2>/dev/null | sort -u | tr '\n' ' '
echo
echo
echo "===== cgroup attach types ====="
grep -oE 'BPF_CGROUP_[A-Z_0-9]+' $K/include/uapi/linux/bpf.h 2>/dev/null | sort -u | tr '\n' ' '
echo
echo
echo "===== cgroup.c hooks implemented ====="
grep -oE '__cgroup_bpf_run_filter_[a-z_]+|BPF_CGROUP_[A-Z_0-9]+' $K/kernel/bpf/cgroup.c 2>/dev/null | sort -u | head -20
echo
echo "===== build progress ====="
tail -2 /tmp/k_build.log 2>/dev/null
echo "errors=$(grep -c 'error:' /tmp/k_build.log 2>/dev/null)"
grep -E '^(build_rc|dtbs_rc)=' /tmp/k_build.log 2>/dev/null || echo "(still running)"
ls -l $K/out/arch/arm64/boot/Image 2>/dev/null
