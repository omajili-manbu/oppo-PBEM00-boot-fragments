#define _GNU_SOURCE
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>

static int kfd = -1;

static void msg(const char *fmt, ...) {
    char b[400];
    va_list ap; va_start(ap, fmt);
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
    buf[n] = 0; return n;
}

static void xmount(const char *src, const char *tgt, const char *fstype,
                   unsigned long flags, const char *data) {
    if (mount(src, tgt, fstype, flags, data) != 0)
        msg("shim4: mount %s -> %s (%s): %s", src ? src : "-", tgt,
            fstype ? fstype : "bind/move", strerror(errno));
}

static void node(const char *path, mode_t mode, unsigned maj, unsigned min) {
    unlink(path);
    if (mknod(path, mode, makedev(maj, min)) != 0)
        msg("shim4: mknod %s: %s", path, strerror(errno));
}

/* re-bind fd 0/1/2 to a console so child output reaches the serial port */
static void bind_console(const char *console, const char *kmsg) {
    int fd = open(console, O_RDWR);
    if (fd >= 0) { dup2(fd, 0); dup2(fd, 1); dup2(fd, 2); if (fd > 2) close(fd); }
    else msg("shim4: cannot open %s: %s", console, strerror(errno));
    int k = open(kmsg, O_WRONLY);
    if (k >= 0) { kfd = k; }
}

static int run_init(const char *arg) {
    msg("shim4: ================ exec /system/bin/init %s ================", arg);
    fflush(NULL);
    pid_t p = fork();
    if (p < 0) { msg("shim4: fork failed: %s", strerror(errno)); return -1; }
    if (p == 0) {
        char *argv[] = { "init", (char *)arg, NULL };
        char *envp[] = { "PATH=/system/bin:/system/xbin", "ANDROID_ROOT=/system",
                         "ANDROID_DATA=/data", NULL };
        execve("/system/bin/init", argv, envp);
        msg("shim4: exec init %s FAILED: %s", arg, strerror(errno));
        _exit(120);
    }
    int st = 0;
    waitpid(p, &st, 0);
    if (WIFEXITED(st))
        msg("shim4: <<< init %s exited code=%d (0x%x)", arg, WEXITSTATUS(st), WEXITSTATUS(st));
    else if (WIFSIGNALED(st))
        msg("shim4: <<< init %s KILLED by signal %d", arg, WTERMSIG(st));
    else
        msg("shim4: <<< init %s status=0x%x", arg, st);
    return WIFEXITED(st) ? WEXITSTATUS(st) : -1;
}

int main(void) {
    mkdir("/proc", 0755); mkdir("/sys", 0755); mkdir("/dev", 0755); mkdir("/newroot", 0755);

    if (mount("devtmpfs", "/dev", "devtmpfs", MS_NOSUID, "mode=0755") != 0) {
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
        mkdir("/dev/__properties__", 0711);
    }
    bind_console("/dev/console", "/dev/kmsg");
    msg("shim4: start - stdio now bound to /dev/console (serial) + kmsg");

    xmount("proc", "/proc", "proc", 0, NULL);
    xmount("sysfs", "/sys", "sysfs", 0, NULL);
    mkdir("/sys/fs/selinux", 0755);
    xmount("selinuxfs", "/sys/fs/selinux", "selinuxfs", 0, NULL);

    struct { const char *name, *node; } blk[] = {
        { "system", "sda11" }, { "odm", "sda12" }, { "userdata", "sda13" },
        { "cache", "sda10" }, { "persist", "sda2" },
    };
    mkdir("/dev/block", 0755);
    mkdir("/dev/block/bootdevice", 0755);
    mkdir("/dev/block/bootdevice/by-name", 0755);
    mkdir("/dev/block/platform", 0755);
    mkdir("/dev/block/platform/soc", 0755);
    mkdir("/dev/block/platform/soc/1d84000.ufshc", 0755);
    mkdir("/dev/block/platform/soc/1d84000.ufshc/by-name", 0755);
    for (unsigned i = 0; i < sizeof blk / sizeof blk[0]; i++) {
        char sysp[128], buf[64], path[128], l1[160], l2[160];
        int maj = -1, min = -1;
        snprintf(sysp, sizeof sysp, "/sys/class/block/%s/dev", blk[i].node);
        if (readf(sysp, buf, sizeof buf) > 0) sscanf(buf, "%d:%d", &maj, &min);
        if (maj < 0) { msg("shim4: WARN no sysfs for %s", blk[i].node); continue; }
        snprintf(path, sizeof path, "/dev/block/%s", blk[i].node);
        node(path, S_IFBLK | 0600, maj, min);
        snprintf(l1, sizeof l1, "/dev/block/platform/soc/1d84000.ufshc/by-name/%s", blk[i].name);
        snprintf(l2, sizeof l2, "/dev/block/bootdevice/by-name/%s", blk[i].name);
        if (symlink(path, l1) != 0) {}
        if (symlink(path, l2) != 0) {}
        if (i == 0) msg("shim4: system = %s (%d:%d)", blk[i].node, maj, min);
    }

    xmount("/dev/block/bootdevice/by-name/system", "/newroot", "ext4", MS_RDONLY, NULL);
    if (access("/newroot/system/bin/init", F_OK) != 0) {
        msg("shim4: FATAL system mount failed, staying alive");
        for (;;) sleep(30);
    }
    const char *tfs[4] = { "/newroot/apex", "/newroot/bootstrap-apex",
                           "/newroot/linkerconfig", "/newroot/mnt" };
    for (int i = 0; i < 4; i++)
        xmount("tmpfs", tfs[i], "tmpfs", MS_NOSUID | MS_NODEV | MS_NOEXEC, "mode=0755");

    xmount("/dev",  "/newroot/dev",  NULL, MS_MOVE, NULL);
    xmount("/proc", "/newroot/proc", NULL, MS_MOVE, NULL);
    xmount("/sys",  "/newroot/sys",  NULL, MS_MOVE, NULL);

    if (chdir("/newroot") != 0 || chroot(".") != 0) {
        msg("shim4: chroot failed: %s", strerror(errno));
        for (;;) sleep(30);
    }
    bind_console("/dev/console", "/dev/kmsg");
    msg("shim4: chroot ok");

    if (access("/vendor/etc/selinux/plat_sepolicy_vers.txt", R_OK) == 0) {
        char v[24] = "?";
        readf("/vendor/etc/selinux/plat_sepolicy_vers.txt", v, sizeof v);
        char *nl = strchr(v, '\n'); if (nl) *nl = 0;
        msg("shim4: /vendor/etc/selinux OK (vers=%s)", v);
    } else
        msg("shim4: WARN /vendor/etc/selinux missing");

    /* is the byte patch present? */
    int fd = open("/system/bin/init", O_RDONLY);
    if (fd >= 0) {
        unsigned char b[4] = {0};
        if (pread(fd, b, 4, 0x11C76C) == 4)
            msg("shim4: init patch @0x11C76C = %02x %02x %02x %02x (want 00 00 80 52)",
                b[0], b[1], b[2], b[3]);
        close(fd);
    }

    int rc1 = run_init("selinux_setup");
    msg("shim4: selinux_setup -> %d", rc1);
    int rc2 = run_init("second_stage");
    msg("shim4: second_stage -> %d", rc2);

    msg("shim4: DIAG DONE, staying alive (no panic)");
    for (;;) { sleep(30); msg("shim4: alive"); }
}
