#define _GNU_SOURCE
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>

static int kfd = -1;

static void msg(const char *fmt, ...) {
    char b[384];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(b, sizeof b, fmt, ap);
    va_end(ap);
    if (n < 0) return;
    if (n > (int)sizeof b - 1) n = sizeof b - 1;
    write(2, b, n); write(2, "\n", 1);
    if (kfd >= 0) { write(kfd, b, n); write(kfd, "\n", 1); }
}

static int readf(const char *p, char *buf, size_t sz) {
    int fd = open(p, O_RDONLY);
    if (fd < 0) return -1;
    int n = read(fd, buf, sz - 1);
    close(fd);
    if (n < 0) return -1;
    buf[n] = 0;
    return n;
}

static void xmount(const char *src, const char *tgt, const char *fstype,
                   unsigned long flags, const char *data) {
    if (mount(src, tgt, fstype, flags, data) != 0)
        msg("hy4shim: mount %s -> %s (%s) failed: %s",
            src ? src : "-", tgt, fstype ? fstype : "bind/move", strerror(errno));
}

static void node(const char *path, mode_t mode, unsigned maj, unsigned min) {
    unlink(path);
    if (mknod(path, mode, makedev(maj, min)) != 0)
        msg("hy4shim: mknod %s failed: %s", path, strerror(errno));
}

int main(void) {
    kfd = open("/dev/kmsg", O_WRONLY);   /* may not exist yet; ok */
    msg("hy4shim: start (v2: tmpfs /dev fallback, sysfs-resolved system dev)");

    mkdir("/proc", 0755); mkdir("/sys", 0755); mkdir("/dev", 0755);
    mkdir("/newroot", 0755);

    /* ---- /dev: devtmpfs if kernel has it, else tmpfs + essential nodes ---- */
    if (mount("devtmpfs", "/dev", "devtmpfs", MS_NOSUID, "mode=0755") != 0) {
        msg("hy4shim: devtmpfs unavailable (%s) -> tmpfs /dev", strerror(errno));
        xmount("tmpfs", "/dev", "tmpfs", MS_NOSUID, "mode=0755");
        node("/dev/null",    S_IFCHR | 0666, 1, 3);
        node("/dev/zero",    S_IFCHR | 0666, 1, 5);
        node("/dev/full",    S_IFCHR | 0666, 1, 7);
        node("/dev/random",  S_IFCHR | 0666, 1, 8);
        node("/dev/urandom", S_IFCHR | 0666, 1, 9);
        node("/dev/kmsg",    S_IFCHR | 0600, 1, 11);
        node("/dev/console", S_IFCHR | 0600, 5, 1);
        node("/dev/tty",     S_IFCHR | 0666, 5, 0);
        node("/dev/ptmx",    S_IFCHR | 0666, 5, 2);
        mkdir("/dev/pts", 0755);
        xmount("devpts", "/dev/pts", "devpts", 0, NULL);
        mkdir("/dev/socket", 0755);
    }
    if (kfd < 0) kfd = open("/dev/kmsg", O_WRONLY);

    xmount("proc", "/proc", "proc", 0, NULL);
    xmount("sysfs", "/sys", "sysfs", 0, NULL);
    mkdir("/sys/fs/selinux", 0755);
    xmount("selinuxfs", "/sys/fs/selinux", "selinuxfs", 0, NULL);

    /* ---- resolve system block device from sysfs (R17: system = sda11) ---- */
    int maj = -1, min = -1;
    char buf[64];
    const char *cands[] = { "/sys/class/block/sda11/dev", "/sys/dev/block/8:11/dev" };
    for (unsigned i = 0; i < sizeof cands / sizeof cands[0] && maj < 0; i++) {
        int n = readf(cands[i], buf, sizeof buf);
        if (n > 0 && sscanf(buf, "%d:%d", &maj, &min) == 2)
            msg("hy4shim: system dev from %s = %d:%d", cands[i], maj, min);
    }
    if (maj < 0) { maj = 8; min = 11; msg("hy4shim: sysfs lookup failed, assume 8:11"); }

    mkdir("/dev/block", 0755);
    node("/dev/block/sda11", S_IFBLK | 0600, maj, min);
    mkdir("/dev/block/bootdevice", 0755);
    mkdir("/dev/block/bootdevice/by-name", 0755);
    mkdir("/dev/block/platform", 0755);
    mkdir("/dev/block/platform/soc", 0755);
    mkdir("/dev/block/platform/soc/1d84000.ufshc", 0755);
    mkdir("/dev/block/platform/soc/1d84000.ufshc/by-name", 0755);
    symlink("/dev/block/sda11", "/dev/block/platform/soc/1d84000.ufshc/by-name/system");
    symlink("/dev/block/sda11", "/dev/block/bootdevice/by-name/system");

    const char *devs[] = {
        "/dev/block/platform/soc/1d84000.ufshc/by-name/system",
        "/dev/block/bootdevice/by-name/system",
        "/dev/block/sda11",
    };
    const char *used = NULL;
    for (unsigned i = 0; i < sizeof devs / sizeof devs[0]; i++) {
        if (access(devs[i], F_OK) == 0) { used = devs[i]; break; }
    }
    if (!used) { msg("hy4shim: FATAL no system block device"); return 1; }
    msg("hy4shim: mounting %s -> /newroot", used);
    xmount(used, "/newroot", "ext4", MS_RDONLY, NULL);
    if (access("/newroot/system/bin/init", F_OK) != 0) {
        msg("hy4shim: FATAL /newroot/system/bin/init missing (mount failed?)");
        return 1;
    }

    /* ---- policies from ramdisk -> /vendor /product /odm ---- */
    const char *subs[3] = { "vendor", "product", "odm" };
    for (int i = 0; i < 3; i++) {
        char src[64], dst[64];
        snprintf(src, sizeof src, "/pol/%s", subs[i]);
        snprintf(dst, sizeof dst, "/newroot/%s", subs[i]);
        xmount(src, dst, NULL, MS_BIND, NULL);
    }
    const char *tfs[4] = { "/newroot/apex", "/newroot/bootstrap-apex",
                           "/newroot/linkerconfig", "/newroot/mnt" };
    for (int i = 0; i < 4; i++)
        xmount("tmpfs", tfs[i], "tmpfs", MS_NOSUID | MS_NODEV | MS_NOEXEC, "mode=0755");

    xmount("/dev",  "/newroot/dev",  NULL, MS_MOVE, NULL);
    xmount("/proc", "/newroot/proc", NULL, MS_MOVE, NULL);
    xmount("/sys",  "/newroot/sys",  NULL, MS_MOVE, NULL);

    if (chdir("/newroot") != 0 || chroot(".") != 0) {
        msg("hy4shim: chroot failed: %s", strerror(errno));
        return 1;
    }
    msg("hy4shim: chroot ok -> exec /system/bin/init second_stage");

    char *argv[] = { "init", "second_stage", NULL };
    char *envp[] = { "PATH=/system/bin:/system/xbin", NULL };
    execve("/system/bin/init", argv, envp);
    msg("hy4shim: exec init failed: %s", strerror(errno));
    return 1;
}
