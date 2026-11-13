#!/bin/bash
K=/home/qwe12/oppo-pbem00-kernel/android_kernel_oppo_sdm710
echo "=== policy version ==="
grep -n 'POLICYDB_VERSION_MAX' $K/security/selinux/include/security.h
grep -rn 'define POLICYDB_VERSION_XPERMS_IOCTL\|define POLICYDB_VERSION_COMPUTE_HASH\|define POLICYDB_VERSION_INFINIBAND\|define POLICYDB_VERSION_GLBLUB' $K/security/selinux/include/*.h 2>/dev/null | head
echo "=== configs (PBEM00) ==="
CONF=$K/arch/arm64/configs/vendor/oplus/PBEM00.config
ls -l $CONF 2>/dev/null
for o in CONFIG_TMPFS_XATTR CONFIG_FS_VERITY CONFIG_PSI CONFIG_CGROUP_BPF CONFIG_BPF_SYSCALL CONFIG_DEVTMPFS_MOUNT CONFIG_ANDROID_BINDERFS CONFIG_MEMCG CONFIG_SECURITY_SELINUX CONFIG_CGROUP_FREEZER CONFIG_USERFAULTFD CONFIG_MEMFD_CREATE CONFIG_BLK_DEV_LOOP CONFIG_TMPFS; do
  v=$(grep -hE "^${o}=|^# ${o} is not set" $CONF 2>/dev/null | head -1)
  echo "${o}: ${v:-<absent>}"
done
echo "=== also check sdm670-perf_defconfig for key ones ==="
D=$K/arch/arm64/configs/vendor/sdm670-perf_defconfig
for o in CONFIG_TMPFS_XATTR CONFIG_DEVTMPFS_MOUNT CONFIG_MEMFD_CREATE CONFIG_USERFAULTFD; do
  v=$(grep -hE "^${o}=" $D 2>/dev/null | head -1); echo "${o}: ${v:-<absent>}"
done
