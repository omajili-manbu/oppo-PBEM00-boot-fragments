# oppo-PBEM00-boot-fragments

OPPO R17 (PBEM00 / SDM670) 刷 HyperOS 4 (Android 17) 的 boot 攻坚进度存档。
日期：2026-11-13。配套内核仓：`omajili-manbu/android_kernel_oppo_sdm710`（4.9.337-perf，自编）。

## 当前状态（一句话）

内核侧四道墙已全部推倒（legacy SAR → DTB fstab → MADV_WIPEONFORK → SELinux），
首阶段 init + switch_root + vendor 挂载实机全通；
当前卡点推进到二阶段 SELinux 之后的 userspace（本轮新内核 `CONFIG_SECURITY_SELINUX=n` 待实机验证）。

## 三件套（刷机清单，2026-11-13 版）

| 镜像 | 刷入分区 | sha256 (前 16) | 说明 |
|---|---|---|---|
| `system_merged.img` | system (sda11) | `70e53838f8e0d1f6` | HyperOS4 system+system_ext+mi_ext 合并，ext4，4,898,947,072 B（4.56GiB=sda11） |
| `vendor_A17fix.img` | vendor (sde15) | `9216950bc91b725f` | ColorOS10 vendor + A17 fstab 语法 + HyperOS 202504 SELinux 策略 |
| `boot_hy4_ns.img` | boot (sde10) | `52db16bc2d3c6096` | 本仓 `images/` 内有完整件 |

### boot_hy4_ns.img 内容
- kernel `d84b5ce6ee9bfce5`：4.9.337-perf #44，含 MADV_WIPEONFORK 回移 + **SELinux/SMACK 整体编译移除**
- kernel_dtb `f949c6b8b20510c2`：DT fstab 补 `system` 条目（vendor 保留启用）
- ramdisk：**小米6 移植包的静态首阶段 init（3,090,824 B）** + 9 个预置 /dev 节点（内核无 devtmpfs）+ 兜底 fstab.qcom；无 Magisk

## 攻关记录（六轮实机，根因链）

### 1. 0x7f00 = magiskinit legacy SAR 不适配 Android 13+
现役 Magisk boot 的 legacy SAR 路径在 A17 上 127/panic。正解：用 ROM 自带静态首阶段 init。

### 2. DTB fstab 缺 system 条目 → switch_root 后 /vendor 被覆盖
OPPO dtsi 的 `android,fstab` 只有 vendor 条目。首阶段 init 找不到 system 条目 → 退回 cmdline root= 直切根 → vendor 条目生效覆盖镜像内文件 → init 读不到策略文件 fatal。
修：`patches/0002-dtb-fstab-add-system-entry.patch`。**实机验证**：`Switching root to '/system'` + vendor 挂载成功。

### 3. MADV_WIPEONFORK（Linux 4.14 特性）缺失 → 任何 A17 动态二进制起不来
A17 bootstrap linker 的 arc4random 初始化 `madvise(MADV_WIPEONFORK)` 失败即 `__dl_abort`（SIGABRT）。
诊断手段：自制 ptrace 追踪 boot（`tools/hy4diag/shim7.c`），从栈回溯定位到 `linker64 lib_off=0xf6b34` 的 `b.eq` 致命分支，反汇编出消息串 `arc4random data MADV_WIPEONFORK failed: %m`。
修：`patches/0001-madv-wipeonfork-backport-4.9.patch`（4 文件 24 行：MADV 18/19 + VM_WIPEONFORK bit23 + madvise 两 case + copy_one_pte 早退）。**实机验证**：告警消失，动态 init 跑通。

### 4. fstab 语法代差（A10 vendor → A17 init）
`resize`/`encryptable=footer` 已被 A17 fs_mgr 移除；`system /`（legacy SAR 挂载点）A17 用户版禁止。
修：重写 `vendor_A17fix.img` 的 `/etc/fstab.qcom` 为 A17 语法（原文件备份 `fstab.qcom.a10bak`）。**实机验证**：`ReadDefaultFstab` 干净通过。

### 5. SELinux 策略代差（v29 vendor vs v33+ system）
A17 init 需 `mapping/29.0.cil`（不存在）→ 换 vendor 策略为 HyperOS 同族 202504（`selinux_a10bak` 备份原件）→ secilc 编译走对版本 → 但编译后 setcon 在"内核无 policy"下必败。
另：曾发现镜像 `mapping/29.0.cil` 有坏 inode（`e2fsck` 本地干净、设备运行时报 deleted inode；疑似刷写层问题），已随 26-29 映射组一并删除（该组本就无用）。
修：`patches/0003-selinux-off-pbem00-config.patch`（`CONFIG_SECURITY_SELINUX=n` + **SMACK 一并关掉**——kconfig 会自动把 SMACK 顶成 major LSM；最终 `CONFIG_DEFAULT_SECURITY_DAC=y`）。init 走原生 "SELinux is disabled" 快车道，编译/加载/setcon/restorecon 全跳过。**本轮待实机验证。**

### 6. 参考资产：小米6 HyperOS4 一键包的解剖结论
`E:\work\oppo-pbem00-kernel\小米6_HyperOS 4.0.30.0.XPCCNXM_pudding_一键刷入`（酷安@酷狗zhj）：
- "HyperOS 3 W-OTA-8" **非官方 OTA**，是社区包（metadata 伪造 MIUI9 基线、post-sdk-level=35）
- 其 `vendor.new.dat` = **phh-treble 血统社区 A15 vendor**（`ro.product.vendor.device=mivendor`、model=`Xiaomi for arm64`、`AP3A.240905.015.A2`、`msm8998` 专用）
- **刷到 cust 分区**（`block_image_update(".../by-name/cust", ...)`），DT fstab `vendor→by-name/cust`，原厂 vendor 分区绕开保留
- 自编 4.4-canary 内核（ACK，带 5.10 eBPF 回移）
- 结论：Mi6 作者的路是"重做 vendor"，R17 无现成 SDM670 社区 vendor，硬适配 A10 vendor 是唯一现实路线

## images/ 之外的产物说明（太大未入库，本地留存）

| 文件 | 大小 | sha256 前 16 | 位置 |
|---|---|---|---|
| system_merged.img | 4.90 GB | `70e53838f8e0d1f6` | `E:\play\MIO-KITCHEN\r17HyperOS4\` |
| vendor_A17fix.img | 2.41 GB | `9216950bc91b725f` | `C:\Users\QWE12\Desktop\` |

## system_merged.img 构建流水线（命令级记录，脚本散失可据此重建）

```bash
# 1. EROFS 解包（WSL, erofs-utils 1.7.1）
fsck.erofs --extract=/root/m/root --force --overwrite system.img
fsck.erofs --extract=/root/m/root/system_ext --force --overwrite system_ext.img
fsck.erofs --extract=/root/m/root/mi_ext --force --overwrite mi_ext.img

# 2. 收割权威元数据（imgkit unpack 输出 fs_config/file_contexts，路径空间带分区名前缀）
imgkit.exe unpack -i system.img -o tree/ --fs-config-path ... --file-contexts-path ...
# 3. 标 security.selinux（收割精确匹配 + 官方 file_contexts 兜底），归一 uid/gid/mode
# 4. 打包（克隆原生底包 r17org/system.img 的 ext4 特性集）
mke2fs -q -F -b 4096 -I 256 -m 0 -t ext4 \
  -O ^has_journal,^64bit,^flex_bg,^dir_index,^metadata_csum,^orphan_file,uninit_bg,ext_attr \
  -U da594c53-9beb-f85c-85c5-cedf76546f7a -d /root/m/root system_merged.img 1196032
# 5. loop 挂载补软链 xattr（mke2fs -d 丢软链 xattr）
# 6. 镜像内补丁：
#    /system/bin/init @0x11C76C: 0x52800020 -> 0x52800000（mov w0,#1 -> #0，SetupSelinux）
#    /system/lib64/libselinux.so security_load_policy @0x12fc4: mov w0,#0; ret
#    /vendor/etc/fstab.qcom: A17 语法重写
#    /system/etc/selinux/mapping: 删除 26-29（无 31 以下映射需求）
```

## 已知问题 / 下一步

1. **本轮 boot_hy4_ns 待实机验证**（SELinux 移除后 init 应走 disabled 快车道，预期 `init second stage started!`）
2. 二阶段预计卡点：apexd（APEX 挂载）、cgroup v2、vold（FDE→FBE 数据升级/清空）、HAL init.rc 兼容
3. netd 长期卡点：cgroup sock/sock_addr BPF 系列缺失（本树只有 CGROUP_SKB + INET_INGRESS/EGRESS）；参考 `psionic_kernel_xiaomi_mido@5.15-bpf`（大量 UPSTREAM/BACKPORT + uname 伪装 5.15 技巧）
4. A10 vendor HAL 与 A17 client 的 HIDL 兼容性是结构性风险

## tools/ 索引

- `hy4diag/shim*.c` — 历代 ramdisk 诊断 shim（v2 建节点 → v4 重绑 stdio → v5 ptrace 回溯 → v7 syscall 级追踪 + /proc/pid/maps 定位）
- `hy4diag/mi6_*.sh`、`init_*.sh`、`cap_cmp.sh` — 小米6 包解剖取证
- `hy4diag/build_*.sh` — 各代 boot 打包
- `hy4diag/sdat2img.py` — transfer.list v4 → raw
- `hy4diag/check_*.sh`、`dis_*.sh`、`chain_dis.sh` — 内核配置/反汇编取证
- `patches/` — 内核树当前全部未提交改动（3 个 patch，+40 行）

## 刷机回退

boot 回退：`boot_flashed.img`（sha `01fd49d1be0ec763`，bootable_337_C7_usbser 原件）。
镜像回退：init 字节 0x11C76C 写回 `0x20`；vendor 的 `fstab.qcom.a10bak` / `selinux_a10bak` 改回原名。
