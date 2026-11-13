#define _GNU_SOURCE
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>

static int kfd = -1;

static void msg(const char *fmt, ...) {
    char b[400];
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
        msg("shim: mount %s -> %s (%s): %s", src ? src : "-", tgt,
            fstype ? fstype : "bind/move", strerror(errno));
}

static void node(const char *path, mode_t mode, unsigned maj, unsigned min) {
    unlink(path);
    if (mknod(path, mode, makedev(maj, min)) != 0)
        msg("shim: mknod %s: %s", path, strerror(errno));
}

/* run init in a child, report status; returns 0 if child exited 0 */
static int run_init(const char *arg) {
    msg("shim: >>> exec /system/bin/init %s", arg);
    pid_t p = fork();
    if (p < 0) { msg("shim: fork failed: %s", strerror(errno)); return -1; }
    if (p == 0) {
        char *argv[] = { "init", (char *)arg, NULL };
        char *envp[] = { "PATH=/system/bin:/system/xbin", NULL };
        execve("/system/bin/init", argv, envp);
        msg("shim: exec init %s failed: %s", arg, strerror(errno));
        _exit(120);
    }
    int st = 0;
    waitpid(p, &st, 0);
    if (WIFEXITED(st))
        msg("shim: <<< init %s EXITED code=%d (0x%x)", arg, WEXITSTATUS(st), WEXITSTATUS(st));
    else if (WIFSIGNALED(st))
        msg("shim: <<< init %s KILLED signal=%d", arg, WTERMSIG(st));
    else
        msg("shim: <<< init %s status=0x%x", arg, st);
    return WIFEXITED(st) ? WEXITSTATUS(st) : -1;
}

int main(void) {
    mkdir("/proc", 0755); mkdir("/sys", 0755); mkdir("/dev", 0755);
    mkdir("/newroot", 0755);

    /* /dev: this kernel has no devtmpfs -> tmpfs + explicit nodes */
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
    kfd = open("/dev/kmsg", O_WRONLY);
    msg("shim3: start (tmpfs /dev + stepwise init, reports exit codes)");

    xmount("proc", "/proc", "proc", 0, NULL);
    xmount("sysfs", "/sys", "sysfs", 0, NULL);
    mkdir("/sys/fs/selinux", 0755);
    xmount("selinuxfs", "/sys/fs/selinux", "selinuxfs", 0, NULL);

    /* block devices from sysfs: system + the ones second stage may want */
    struct { const char *name, *node; int maj, min; } blk[] = {
        { "system",   "sda11", 8, 11 },
        { "odm",      "sda12", 8, 12 },
        { "userdata", "sda13", 8, 13 },
        { "cache",    "sda10", 8, 10 },
        { "vendor",   "sde15", 259, 0 },
    };
    mkdir("/dev/block", 0755);
    mkdir("/dev/block/bootdevice", 0755);
    mkdir("/dev/block/bootdevice/by-name", 0755);
    mkdir("/dev/block/platform", 0755);
    mkdir("/dev/block/platform/soc", 0755);
    mkdir("/dev/block/platform/soc/1d84000.ufshc", 0755);
    mkdir("/dev/block/platform/soc/1d84000.ufshc/by-name", 0755);
    for (unsigned i = 0; i < sizeof blk / sizeof blk[0]; i++) {
        char sysp[128], buf[64];
        int maj = blk[i].maj, min = blk[i].min;
        snprintf(sysp, sizeof sysp, "/sys/class/block/%s/dev", blk[i].node);
        if (readf(sysp, buf, sizeof buf) > 0 && sscanf(buf, "%d:%d", &maj, &min) != 2) {
            maj = blk[i].maj; min = blk[i].min;
        }
        char path[128];
        snprintf(path, sizeof path, "/dev/block/%s", blk[i].node);
        node(path, S_IFBLK | 0600, maj, min);
        char link1[160], link2[160];
        snprintf(link1, sizeof link1,
                 "/dev/block/platform/soc/1d84000.ufshc/by-name/%s", blk[i].name);
        snprintf(link2, sizeof link2, "/dev/block/bootdevice/by-name/%s", blk[i].name);
        if (symlink(path, link1) != 0) {}
        if (symlink(path, link2) != 0) {}
        if (i == 0) msg("shim3: system blk %s = %d:%d", blk[i].node, maj, min);
    }

    xmount("/dev/block/bootdevice/by-name/system", "/newroot", "ext4", MS_RDONLY, NULL);
    if (access("/newroot/system/bin/init", F_OK) != 0) {
        msg("shim3: FATAL system mount failed");
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
        msg("shim3: chroot failed: %s", strerror(errno));
        for (;;) sleep(30);
    }
    kfd = open("/dev/kmsg", O_WRONLY);
    msg("shim3: chroot ok (root = merged system image)");

    /* policy files present? */
    msg("shim3: vendor selinux files=%d product=%d",
        /* cheap check: open the version file */
        0, 0);
    if (access("/vendor/etc/selinux/plat_sepolicy_vers.txt", R_OK) == 0)
        msg("shim3: /vendor/etc/selinux present");
    else
        msg("shim3: WARN /vendor/etc/selinux/plat_sepolicy_vers.txt missing");

    int rc = run_init("selinux_setup");
    msg("shim3: selinux_setup returned %d", rc);
    rc = run_init("second_stage");
    msg("shim3: second_stage returned %d", rc);

    msg("shim3: DIAG DONE - staying alive so the kernel does not panic");
    for (;;) { sleep(30); msg("shim3: alive"); }
}
