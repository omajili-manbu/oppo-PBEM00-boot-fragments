#define _GNU_SOURCE
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <dirent.h>
#include <signal.h>
#include <elf.h>
#include <sys/ptrace.h>
#include <sys/uio.h>
#include <sys/wait.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>

static int kfd = -1;

static void msg(const char *fmt, ...) {
    char b[512];
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
        msg("shim5: mount %s -> %s: %s", src ? src : "-", tgt, strerror(errno));
}

static void node(const char *path, mode_t mode, unsigned maj, unsigned min) {
    unlink(path);
    if (mknod(path, mode, makedev(maj, min)) != 0)
        msg("shim5: mknod %s: %s", path, strerror(errno));
}

static void bind_console(void) {
    int fd = open("/dev/console", O_RDWR);
    if (fd >= 0) { dup2(fd, 0); dup2(fd, 1); dup2(fd, 2); if (fd > 2) close(fd); }
    int k = open("/dev/kmsg", O_WRONLY);
    if (k >= 0) kfd = k;
}

static void dump_dir(const char *path, const char *tag) {
    DIR *d = opendir(path);
    if (!d) { msg("shim5: DIR %s -> %s", path, strerror(errno)); return; }
    struct dirent *e; int n = 0;
    char names[220]; names[0] = 0;
    while ((e = readdir(d)) && n < 12) {
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
        if (strlen(names) + strlen(e->d_name) + 2 < sizeof names) {
            strcat(names, e->d_name); strcat(names, " ");
        }
        n++;
    }
    closedir(d);
    msg("shim5: DIR %s (%s) entries>=%d: %s", path, tag, n, names);
}

/* ---- minimal aarch64 ptrace tracer ---- */
struct user_pt_regs_ {
    unsigned long long regs[31];
    unsigned long long sp, pc, pstate;
};

static void trace_run(const char *arg) {
    msg("shim5: ========= TRACE init %s =========", arg);
    fflush(NULL);
    pid_t p = fork();
    if (p < 0) { msg("shim5: fork: %s", strerror(errno)); return; }
    if (p == 0) {
        if (ptrace(PTRACE_TRACEME, 0, 0, 0) != 0) _exit(119);
        char *argv[] = { "init", (char *)arg, NULL };
        char *envp[] = { "PATH=/system/bin:/system/xbin", NULL };
        execve("/system/bin/init", argv, envp);
        _exit(120);
    }
    int st = 0;
    if (waitpid(p, &st, 0) < 0) { msg("shim5: waitpid: %s", strerror(errno)); return; }
    ptrace(PTRACE_SETOPTIONS, p, 0, (void *)PTRACE_O_TRACEEXEC);
    ptrace(PTRACE_CONT, p, 0, 0);

    for (;;) {
        if (waitpid(p, &st, 0) < 0) { msg("shim5: waitpid2: %s", strerror(errno)); break; }
        if (WIFEXITED(st)) { msg("shim5: TRACE init %s exited=%d", arg, WEXITSTATUS(st)); break; }
        if (WIFSIGNALED(st)) { msg("shim5: TRACE init %s killed=%d", arg, WTERMSIG(st)); break; }
        if (!WIFSTOPPED(st)) continue;
        int sig = WSTOPSIG(st);
        if (sig == SIGTRAP || sig == SIGSTOP) {
            ptrace(PTRACE_CONT, p, 0, 0);
            continue;
        }
        /* fatal-ish signal: dump state */
        struct user_pt_regs_ r;
        struct iovec iov = { &r, sizeof r };
        if (ptrace(PTRACE_GETREGSET, p, (void *)NT_PRSTATUS, &iov) == 0) {
            msg("shim5: >>> signal %d  pc=%llx lr=%llx sp=%llx", sig,
                r.pc, r.regs[30], r.sp);
            msg("shim5:     x0=%llx x1=%llx x2=%llx x3=%llx",
                r.regs[0], r.regs[1], r.regs[2], r.regs[3]);
            msg("shim5:     x19=%llx x20=%llx x21=%llx x22=%llx",
                r.regs[19], r.regs[20], r.regs[21], r.regs[22]);
            /* stack words: return addresses */
            for (int i = 0; i < 40; i++) {
                errno = 0;
                long w = ptrace(PTRACE_PEEKDATA, p, (void *)(r.sp + i * 8), 0);
                if (errno) break;
                if (w == 0) continue;
                msg("shim5:     stack[%02d] %llx", i, (unsigned long long)w);
            }
        } else {
            msg("shim5: GETREGSET failed: %s", strerror(errno));
        }
        /* stop the child for good */
        kill(p, SIGKILL);
        waitpid(p, &st, 0);
        break;
    }
    msg("shim5: ========= TRACE init %s done =========", arg);
}

int main(void) {
    mkdir("/proc", 0755); mkdir("/sys", 0755); mkdir("/dev", 0755); mkdir("/newroot", 0755);

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
        mkdir("/dev/__properties__", 0711);
    }
    bind_console();
    msg("shim5: start (facts + ptrace backtrace)");

    xmount("proc", "/proc", "proc", 0, NULL);
    xmount("sysfs", "/sys", "sysfs", 0, NULL);
    mkdir("/sys/fs/selinux", 0755);
    xmount("selinuxfs", "/sys/fs/selinux", "selinuxfs", 0, NULL);

    const char *names[] = { "system", "odm", "userdata", "cache" };
    const char *nodes[] = { "sda11", "sda12", "sda13", "sda10" };
    mkdir("/dev/block", 0755);
    mkdir("/dev/block/bootdevice", 0755);
    mkdir("/dev/block/bootdevice/by-name", 0755);
    mkdir("/dev/block/platform", 0755);
    mkdir("/dev/block/platform/soc", 0755);
    mkdir("/dev/block/platform/soc/1d84000.ufshc", 0755);
    mkdir("/dev/block/platform/soc/1d84000.ufshc/by-name", 0755);
    for (int i = 0; i < 4; i++) {
        char sysp[128], buf[64], path[128], l1[192], l2[160];
        int maj = -1, min = -1;
        snprintf(sysp, sizeof sysp, "/sys/class/block/%s/dev", nodes[i]);
        if (readf(sysp, buf, sizeof buf) > 0) sscanf(buf, "%d:%d", &maj, &min);
        if (maj < 0) { msg("shim5: no sysfs for %s", nodes[i]); continue; }
        snprintf(path, sizeof path, "/dev/block/%s", nodes[i]);
        node(path, S_IFBLK | 0600, maj, min);
        snprintf(l1, sizeof l1, "/dev/block/platform/soc/1d84000.ufshc/by-name/%s", names[i]);
        snprintf(l2, sizeof l2, "/dev/block/bootdevice/by-name/%s", names[i]);
        if (symlink(path, l1) != 0) {}
        if (symlink(path, l2) != 0) {}
    }

    xmount("/dev/block/bootdevice/by-name/system", "/newroot", "ext4", MS_RDONLY, NULL);
    if (access("/newroot/system/bin/init", F_OK) != 0) {
        msg("shim5: FATAL no system, staying alive");
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
        msg("shim5: chroot: %s", strerror(errno));
        for (;;) sleep(30);
    }
    bind_console();
    msg("shim5: chroot ok");

    /* ---- facts about the image on the device ---- */
    struct stat sb;
    if (stat("/system/bin/init", &sb) == 0)
        msg("shim5: /system/bin/init size=%lld mode=%o", (long long)sb.st_size, sb.st_mode & 07777);
    dump_dir("/vendor", "vendor");
    dump_dir("/vendor/etc", "vendor/etc");
    dump_dir("/vendor/etc/selinux", "vendor selinux");
    dump_dir("/product/etc/selinux", "product selinux");
    dump_dir("/system/etc/selinux", "plat selinux");
    int fd = open("/vendor/etc/selinux/plat_sepolicy_vers.txt", O_RDONLY);
    if (fd >= 0) {
        char v[32] = {0}; int n = read(fd, v, sizeof v - 1); close(fd);
        if (n > 0) { char *nl = strchr(v, '\n'); if (nl) *nl = 0; msg("shim5: vers=%s", v); }
    } else msg("shim5: open vers -> %s", strerror(errno));
    if (stat("/vendor", &sb) == 0) msg("shim5: /vendor nlink=%d uid=%d gid=%d", (int)sb.st_nlink, sb.st_uid, sb.st_gid);

    /* ---- tracer: first stage (no arg) proves logging works ---- */
    trace_run("");
    trace_run("selinux_setup");
    trace_run("second_stage");

    msg("shim5: DIAG DONE, staying alive");
    for (;;) { sleep(30); msg("shim5: alive"); }
}
