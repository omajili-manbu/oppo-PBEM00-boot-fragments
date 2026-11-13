#define _GNU_SOURCE
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <elf.h>
#include <sys/ptrace.h>
#include <sys/uio.h>
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
        msg("shim7: mount %s -> %s (%s): %s", src ? src : "-", tgt,
            fstype ? fstype : "bind", strerror(errno));
}

static void node(const char *path, mode_t mode, unsigned maj, unsigned min) {
    unlink(path);
    if (mknod(path, mode, makedev(maj, min)) != 0)
        msg("shim7: mknod %s: %s", path, strerror(errno));
}

static void bind_console(void) {
    int fd = open("/dev/console", O_RDWR);
    if (fd >= 0) { dup2(fd, 0); dup2(fd, 1); dup2(fd, 2); if (fd > 2) close(fd); }
    int k = open("/dev/kmsg", O_WRONLY);
    if (k >= 0) kfd = k;
}

static const char *sysname(long n) {
    switch (n) {
    case 39: return "umount2"; case 40: return "mount"; case 56: return "openat";
    case 57: return "close"; case 61: return "getdents64"; case 63: return "read";
    case 64: return "write"; case 73: return "ppoll"; case 78: return "readlinkat";
    case 79: return "newfstatat"; case 80: return "fstat"; case 94: return "exit_group";
    case 96: return "set_tid_address"; case 99: return "set_robust_list";
    case 134: return "rt_sigaction"; case 135: return "rt_sigprocmask";
    case 160: return "uname"; case 167: return "prctl"; case 172: return "getpid";
    case 174: return "getuid"; case 198: return "socket"; case 203: return "connect";
    case 206: return "sendto"; case 207: return "recvfrom"; case 215: return "munmap";
    case 220: return "clone"; case 221: return "execve"; case 222: return "mmap";
    case 233: return "madvise"; case 260: return "wait4";
    case 278: return "getrandom";
    default: return "";
    }
}

struct user_pt_regs_ { unsigned long long regs[31], sp, pc, pstate; };

static void peek_str(pid_t p, unsigned long long addr, char *out, int max) {
    out[0] = 0;
    if (!addr) return;
    unsigned long long a = addr & ~7ULL;
    int skip = (int)(addr - a), i = 0;
    while (i < max - 1) {
        errno = 0;
        long w = ptrace(PTRACE_PEEKDATA, p, (void *)a, 0);
        if (errno) break;
        char *b = (char *)&w;
        for (int k = skip; k < 8 && i < max - 1; k++) {
            if (b[k] == 0) { out[i] = 0; return; }
            out[i++] = b[k];
        }
        skip = 0; a += 8;
    }
    out[i] = 0;
}

static int find_map(pid_t p, unsigned long long pc, char *out, size_t outsz) {
    char path[64];
    snprintf(path, sizeof path, "/proc/%d/maps", (int)p);
    int fd = open(path, O_RDONLY);
    if (fd < 0) return -1;
    char chunk[2048], line[512];
    size_t ll = 0;
    int found = 0;
    ssize_t n;
    while (!found && (n = read(fd, chunk, sizeof chunk)) > 0) {
        for (ssize_t i = 0; i < n; i++) {
            char c = chunk[i];
            if (c != '\n') {
                if (ll < sizeof line - 1) line[ll++] = c;
                continue;
            }
            line[ll] = 0; ll = 0;
            unsigned long long s = 0, e = 0, off = 0;
            char perms[8] = {0};
            if (sscanf(line, "%llx-%llx %7s %llx", &s, &e, perms, &off) != 4) continue;
            if (pc >= s && pc < e) {
                char *sp = strchr(line, '/');
                snprintf(out, outsz, "%s (lib_off=0x%llx map=[%llx-%llx] fileoff=0x%llx perms=%s)",
                         sp ? sp : "(anon)", pc - s + off, s, e, off, perms);
                found = 1;
                break;
            }
        }
    }
    close(fd);
    return found ? 0 : -1;
}

static void dump_maps_entry(pid_t p, unsigned long long pc, const char *tag) {
    char info[256];
    if (find_map(p, pc, info, sizeof info) == 0)
        msg("shim7: %s pc=%llx IN %s", tag, pc, info);
    else
        msg("shim7: %s pc=%llx not found in maps", tag, pc);
}

static void run_traced(const char *arg) {
    msg("shim7: ===== traced exec: /system/bin/init %s =====", arg);
    fflush(NULL);
    pid_t p = fork();
    if (p < 0) { msg("shim7: fork: %s", strerror(errno)); return; }
    if (p == 0) {
        ptrace(PTRACE_TRACEME, 0, 0, 0);
        char *argv[] = { "init", (char *)arg, NULL };
        char *envp[] = { "PATH=/system/bin:/system/xbin", NULL };
        execve("/system/bin/init", argv, envp);
        _exit(120);
    }
    int st = 0, entering = 1, count = 0;
    long prev_nr = -1;
    char lastpath[96] = "";
    if (waitpid(p, &st, 0) < 0) { msg("shim7: waitpid: %s", strerror(errno)); return; }
    ptrace(PTRACE_SYSCALL, p, 0, 0);
    for (;;) {
        if (waitpid(p, &st, 0) < 0) break;
        if (WIFEXITED(st)) { msg("shim7: init %s EXITED %d", arg, WEXITSTATUS(st)); break; }
        if (WIFSIGNALED(st)) { msg("shim7: init %s KILLED sig=%d", arg, WTERMSIG(st)); break; }
        if (!WIFSTOPPED(st)) continue;
        int sig = WSTOPSIG(st);
        if (sig != SIGTRAP) {
            struct user_pt_regs_ r;
            struct iovec iov = { &r, sizeof r };
            if (ptrace(PTRACE_GETREGSET, p, (void *)NT_PRSTATUS, &iov) == 0) {
                msg("shim7: >>> sig %d pc=%llx lr=%llx sp=%llx x0=%llx x1=%llx",
                    sig, r.pc, r.regs[30], r.sp, r.regs[0], r.regs[1]);
                dump_maps_entry(p, r.pc, "PC");
                dump_maps_entry(p, r.regs[30], "LR");
                /* walk the stack: mark words that land in executable mappings */
                for (int i = 0; i < 48; i++) {
                    errno = 0;
                    long w = ptrace(PTRACE_PEEKDATA, p, (void *)(r.sp + i * 8), 0);
                    if (errno) break;
                    if (!w) continue;
                    char info[256];
                    if (find_map(p, (unsigned long long)w, info, sizeof info) == 0) {
                        if (strstr(info, "r-xp"))
                            msg("shim7:   stack[%02d] %llx -> CODE IN %s", i,
                                (unsigned long long)w, info);
                        else
                            msg("shim7:   stack[%02d] %llx -> %s", i,
                                (unsigned long long)w, info);
                    } else if (i < 8) {
                        msg("shim7:   stack[%02d] %llx", i, (unsigned long long)w);
                    }
                }
            }
            ptrace(PTRACE_SYSCALL, p, 0, sig);
            continue;
        }
        struct user_pt_regs_ r;
        struct iovec iov = { &r, sizeof r };
        if (ptrace(PTRACE_GETREGSET, p, (void *)NT_PRSTATUS, &iov) != 0) {
            ptrace(PTRACE_SYSCALL, p, 0, 0);
            continue;
        }
        long nr = (long)r.regs[8];
        if (entering) {
            prev_nr = nr;
            if (nr == 56) {                       /* openat */
                peek_str(p, r.regs[1], lastpath, sizeof lastpath);
                if (count < 700) msg("shim7: [%d] openat \"%s\" flags=%llx",
                                     count, lastpath, r.regs[2]);
            } else if (nr == 40 || nr == 221 || nr == 198 || nr == 203) {
                msg("shim7: [%d] %s(%ld) x0=%llx x1=%llx x2=%llx", count,
                    sysname(nr), nr, r.regs[0], r.regs[1], r.regs[2]);
            } else if (count < 250) {
                msg("shim7: [%d] %s(%ld) x0=%llx x1=%llx", count, sysname(nr), nr,
                    r.regs[0], r.regs[1]);
            }
            count++;
        } else {
            long ret = (long)r.regs[0];
            if (prev_nr == 56) {
                if (ret < 0)
                    msg("shim7:     !! openat FAILED ret=%ld (%s) path=\"%s\"",
                        ret, strerror((int)-ret), lastpath);
            } else if (prev_nr == 40 || prev_nr == 221 || prev_nr == 198 || prev_nr == 203) {
                if (ret < 0)
                    msg("shim7:     !! %s FAILED ret=%ld (%s)", sysname(prev_nr), ret,
                        strerror((int)-ret));
                else
                    msg("shim7:     ^^ %s ret=%ld", sysname(prev_nr), ret);
            }
        }
        entering = !entering;
        ptrace(PTRACE_SYSCALL, p, 0, 0);
    }
    msg("shim7: ===== traced exec done (%d syscall entries) =====", count);
}

int main(void) {
    mkdir("/proc", 0755); mkdir("/sys", 0755); mkdir("/dev", 0755); mkdir("/newroot", 0755);

    if (mount("devtmpfs", "/dev", "devtmpfs", MS_NOSUID, "mode=0755") != 0) {
        xmount("tmpfs", "/dev", "tmpfs", MS_NOSUID, "mode=0755");
        node("/dev/null", S_IFCHR|0666, 1, 3);  node("/dev/zero", S_IFCHR|0666, 1, 5);
        node("/dev/random", S_IFCHR|0666, 1, 8); node("/dev/urandom", S_IFCHR|0666, 1, 9);
        node("/dev/kmsg", S_IFCHR|0600, 1, 11);  node("/dev/console", S_IFCHR|0600, 5, 1);
        node("/dev/tty", S_IFCHR|0666, 5, 0);    node("/dev/ptmx", S_IFCHR|0666, 5, 2);
        mkdir("/dev/pts", 0755); xmount("devpts", "/dev/pts", "devpts", 0, NULL);
        mkdir("/dev/socket", 0755); mkdir("/dev/__properties__", 0711);
    }
    bind_console();
    msg("shim7: start (reproduce real flow: system + vendor mounts, traced init)");

    xmount("proc", "/proc", "proc", 0, NULL);
    xmount("sysfs", "/sys", "sysfs", 0, NULL);
    mkdir("/sys/fs/selinux", 0755);
    xmount("selinuxfs", "/sys/fs/selinux", "selinuxfs", 0, NULL);

    struct { const char *name, *node; } blk[] = {
        { "system", "sda11" }, { "odm", "sda12" }, { "userdata", "sda13" },
        { "cache", "sda10" }, { "vendor", "sde15" },
    };
    mkdir("/dev/block", 0755);
    mkdir("/dev/block/bootdevice", 0755); mkdir("/dev/block/bootdevice/by-name", 0755);
    mkdir("/dev/block/platform", 0755); mkdir("/dev/block/platform/soc", 0755);
    mkdir("/dev/block/platform/soc/1d84000.ufshc", 0755);
    mkdir("/dev/block/platform/soc/1d84000.ufshc/by-name", 0755);
    for (unsigned i = 0; i < sizeof blk / sizeof blk[0]; i++) {
        char sysp[128], buf[64], path[128], l1[192], l2[160];
        int maj = -1, min = -1;
        snprintf(sysp, sizeof sysp, "/sys/class/block/%s/dev", blk[i].node);
        if (readf(sysp, buf, sizeof buf) > 0) sscanf(buf, "%d:%d", &maj, &min);
        if (maj < 0) { msg("shim7: no sysfs %s", blk[i].node); continue; }
        snprintf(path, sizeof path, "/dev/block/%s", blk[i].node);
        node(path, S_IFBLK|0600, maj, min);
        snprintf(l1, sizeof l1, "/dev/block/platform/soc/1d84000.ufshc/by-name/%s", blk[i].name);
        snprintf(l2, sizeof l2, "/dev/block/bootdevice/by-name/%s", blk[i].name);
        if (symlink(path, l1)) {} if (symlink(path, l2)) {}
        if (i == 0) msg("shim7: system=%s %d:%d", blk[i].node, maj, min);
    }

    xmount("/dev/block/bootdevice/by-name/system", "/newroot", "ext4", MS_RDONLY, NULL);
    if (access("/newroot/system/bin/init", F_OK) != 0) {
        msg("shim7: FATAL no system"); for (;;) sleep(30);
    }
    /* NEW: mount the real vendor partition like first stage does */
    mkdir("/newroot/vendor", 0755);
    xmount("/dev/block/bootdevice/by-name/vendor", "/newroot/vendor", "ext4", MS_RDONLY, NULL);
    if (access("/newroot/vendor/etc/selinux/plat_sepolicy_vers.txt", R_OK) == 0) {
        char v[24] = "?"; readf("/newroot/vendor/etc/selinux/plat_sepolicy_vers.txt", v, sizeof v);
        char *nl = strchr(v, '\n'); if (nl) *nl = 0;
        msg("shim7: vendor(real) plat_sepolicy_vers=%s", v);
    } else msg("shim7: vendor(real) has no plat_sepolicy_vers.txt");

    const char *tfs[4] = { "/newroot/apex", "/newroot/bootstrap-apex",
                           "/newroot/linkerconfig", "/newroot/mnt" };
    for (int i = 0; i < 4; i++)
        xmount("tmpfs", tfs[i], "tmpfs", MS_NOSUID|MS_NODEV|MS_NOEXEC, "mode=0755");

    xmount("/dev", "/newroot/dev", NULL, MS_MOVE, NULL);
    xmount("/proc", "/newroot/proc", NULL, MS_MOVE, NULL);
    xmount("/sys", "/newroot/sys", NULL, MS_MOVE, NULL);

    if (chdir("/newroot") != 0 || chroot(".") != 0) {
        msg("shim7: chroot: %s", strerror(errno)); for (;;) sleep(30);
    }
    bind_console();
    msg("shim7: chroot ok");

    /* init 会把 stdio 重定向到 /dev/null，把 LOG 一起吞掉；
       bind console 到 /dev/null，让这些输出直上串口 */
    xmount("/dev/console", "/dev/null", NULL, MS_BIND, NULL);
    msg("shim7: /dev/null -> console bound (init's LOG now visible)");

    run_traced("selinux_setup");
    msg("shim7: DIAG DONE, staying alive");
    for (;;) { sleep(30); msg("shim7: alive"); }
}
