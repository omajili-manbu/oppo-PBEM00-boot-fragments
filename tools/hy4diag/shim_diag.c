#define _GNU_SOURCE
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <sched.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <sys/mman.h>

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
        msg("hy4diag: mount %s -> %s (%s): %s", src ? src : "-", tgt,
            fstype ? fstype : "bind/move", strerror(errno));
}

static void node(const char *path, mode_t mode, unsigned maj, unsigned min) {
    unlink(path);
    if (mknod(path, mode, makedev(maj, min)) != 0)
        msg("hy4diag: mknod %s: %s", path, strerror(errno));
}

struct job { const char *path; char *const *argv; const char *tag; };

static int child_run(void *arg) {
    struct job *j = arg;
    execv(j->path, j->argv);
    msg("hy4diag: [%s] exec %s failed: %s", j->tag, j->path, strerror(errno));
    _exit(111);
}

static void run_job(struct job *j) {
    /* new PID namespace => child becomes PID1 there, reboot() gets EPERM */
    size_t stack_sz = 256 * 1024;
    void *stack = mmap(NULL, stack_sz, PROT_READ | PROT_WRITE,
                       MAP_PRIVATE | MAP_ANONYMOUS | MAP_STACK, -1, 0);
    if (stack == MAP_FAILED) { msg("hy4diag: [%s] mmap stack failed", j->tag); return; }
    msg("hy4diag: ===== [%s] %s =====", j->tag, j->path);
    int pid = clone(child_run, (char *)stack + stack_sz, CLONE_NEWPID | SIGCHLD, j);
    if (pid < 0) { msg("hy4diag: [%s] clone failed: %s", j->tag, strerror(errno)); return; }
    int st = 0;
    waitpid(pid, &st, 0);
    if (WIFEXITED(st))      msg("hy4diag: [%s] exit=%d", j->tag, WEXITSTATUS(st));
    else if (WIFSIGNALED(st)) msg("hy4diag: [%s] killed by signal %d", j->tag, WTERMSIG(st));
    else                    msg("hy4diag: [%s] status=0x%x", j->tag, st);
}

int main(void) {
    mkdir("/proc", 0755); mkdir("/sys", 0755); mkdir("/dev", 0755);
    mkdir("/newroot", 0755);

    if (mount("devtmpfs", "/dev", "devtmpfs", MS_NOSUID, "mode=0755") != 0) {
        xmount("tmpfs", "/dev", "tmpfs", MS_NOSUID, "mode=0755");
        node("/dev/null",    S_IFCHR | 0666, 1, 3);
        node("/dev/zero",    S_IFCHR | 0666, 1, 5);
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
    kfd = open("/dev/kmsg", O_WRONLY);

    xmount("proc", "/proc", "proc", 0, NULL);
    xmount("sysfs", "/sys", "sysfs", 0, NULL);
    mkdir("/sys/fs/selinux", 0755);
    xmount("selinuxfs", "/sys/fs/selinux", "selinuxfs", 0, NULL);

    char ver[256] = {0};
    if (readf("/proc/version", ver, sizeof ver) > 0) {
        char *nl = strchr(ver, '\n'); if (nl) *nl = 0;
        msg("hy4diag: kernel: %s", ver);
    }

    int maj = -1, min = -1;
    char buf[64];
    if (readf("/sys/class/block/sda11/dev", buf, sizeof buf) > 0)
        sscanf(buf, "%d:%d", &maj, &min);
    if (maj < 0) { maj = 8; min = 11; }
    mkdir("/dev/block", 0755);
    node("/dev/block/sda11", S_IFBLK | 0600, maj, min);
    mkdir("/dev/block/platform", 0755);
    mkdir("/dev/block/platform/soc", 0755);
    mkdir("/dev/block/platform/soc/1d84000.ufshc", 0755);
    mkdir("/dev/block/platform/soc/1d84000.ufshc/by-name", 0755);
    if (symlink("/dev/block/sda11", "/dev/block/platform/soc/1d84000.ufshc/by-name/system") != 0) {}
    xmount("/dev/block/platform/soc/1d84000.ufshc/by-name/system", "/newroot", "ext4", MS_RDONLY, NULL);

    const char *subs[3] = { "vendor", "product", "odm" };
    for (int i = 0; i < 3; i++) {
        char src[64], dst[64];
        snprintf(src, sizeof src, "/pol/%s", subs[i]);
        snprintf(dst, sizeof dst, "/newroot/%s", subs[i]);
        xmount(src, dst, NULL, MS_BIND, NULL);
    }
    const char *tfs[3] = { "/newroot/apex", "/newroot/bootstrap-apex", "/newroot/linkerconfig" };
    for (int i = 0; i < 3; i++)
        xmount("tmpfs", tfs[i], "tmpfs", MS_NOSUID | MS_NODEV | MS_NOEXEC, "mode=0755");
    xmount("/dev",  "/newroot/dev",  NULL, MS_MOVE, NULL);
    xmount("/proc", "/newroot/proc", NULL, MS_MOVE, NULL);
    xmount("/sys",  "/newroot/sys",  NULL, MS_MOVE, NULL);
    if (chdir("/newroot") != 0 || chroot(".") != 0) { msg("hy4diag: chroot failed"); return 1; }

    kfd = open("/dev/kmsg", O_WRONLY);
    msg("hy4diag: chroot ok, probing (this is diagnostic, no boot)");
    const char *checks[] = { "/system/bin/init", "/system/bin/bootstrap/linker64",
                             "/system/lib64/bootstrap/libc.so", "/system/etc/linker.config.pb",
                             "/system/etc/init/hw/init.rc", "/vendor/etc/selinux/plat_sepolicy_vers.txt" };
    for (unsigned i = 0; i < sizeof checks / sizeof checks[0]; i++)
        msg("hy4diag: access %s -> %s", checks[i], access(checks[i], R_OK) == 0 ? "OK" : strerror(errno));

    char *a_static[] = { "toolbox_ramdisk", NULL };
    struct job j1 = { "/system/bin/toolbox_ramdisk", a_static, "static-control" };
    run_job(&j1);

    char *a_list[] = { "linker64", "--list", "/system/bin/init", NULL };
    struct job j2 = { "/system/bin/bootstrap/linker64", a_list, "linker--list" };
    run_job(&j2);

    char *a_ss[] = { "init", "selinux_setup", NULL };
    struct job j3 = { "/system/bin/init", a_ss, "init-selinux_setup" };
    run_job(&j3);

    char *a_s2[] = { "init", "second_stage", NULL };
    struct job j4 = { "/system/bin/init", a_s2, "init-second_stage" };
    run_job(&j4);

    msg("hy4diag: DIAG COMPLETE - device will stay here; power-cycle when done");
    for (;;) { sleep(30); msg("hy4diag: alive"); }
}
