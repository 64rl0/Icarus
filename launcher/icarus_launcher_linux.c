#include <errno.h>
#include <limits.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static pid_t child_pid = -1;

static void forward_signal(int sig) {
    if (child_pid > 0) {
        kill(child_pid, sig);
    }
}

static int ascend_dir(char *path, int levels) {
    for (int i = 0; i < levels; i++) {
        char *slash = strrchr(path, '/');
        if (slash == NULL) {
            errno = EINVAL;
            return -1;
        }
        if (slash == path) {
            path[1] = '\0';
        } else {
            *slash = '\0';
        }
    }
    return 0;
}

static int resolve_exe_dir(char *out, size_t out_len) {
    ssize_t len = readlink("/proc/self/exe", out, out_len - 1);
    if (len < 0) {
        return -1;
    }
    out[len] = '\0';

    char resolved[PATH_MAX];
    if (realpath(out, resolved) == NULL) {
        return -1;
    }

    strncpy(out, resolved, out_len - 1);
    out[out_len - 1] = '\0';

    char *slash = strrchr(out, '/');
    if (slash == NULL) {
        errno = EINVAL;
        return -1;
    }

    *slash = '\0';
    return 0;
}

int main(int argc, char *argv[]) {
    char exe_dir[PATH_MAX];
    if (resolve_exe_dir(exe_dir, sizeof(exe_dir)) != 0) {
        fprintf(stderr, "Failed to resolve launcher path: %s\n", strerror(errno));
        return 1;
    }

    char project_root_dir[PATH_MAX];
    strncpy(project_root_dir, exe_dir, sizeof(project_root_dir) - 1);
    project_root_dir[sizeof(project_root_dir) - 1] = '\0';
    if (ascend_dir(project_root_dir, 4) != 0) {
        fprintf(stderr, "Failed to resolve project root: %s\n", strerror(errno));
        return 1;
    }

    char script_path[PATH_MAX];
    if (snprintf(script_path, sizeof(script_path), "%s/scripts/icarus.sh", project_root_dir) >=
        (int)sizeof(script_path)) {
        fprintf(stderr, "Script path too long.\n");
        return 1;
    }

    if (access(script_path, R_OK) != 0) {
        fprintf(stderr, "Missing launcher script: %s\n", script_path);
        return 1;
    }

    char **child_argv = calloc((size_t)argc + 2, sizeof(char *));
    if (child_argv == NULL) {
        fprintf(stderr, "Failed to allocate argv.\n");
        return 1;
    }

    child_argv[0] = "/bin/bash";
    child_argv[1] = script_path;
    for (int i = 1; i < argc; i++) {
        child_argv[i + 1] = argv[i];
    }
    child_argv[argc + 1] = NULL;

    pid_t pid = fork();
    if (pid < 0) {
        fprintf(stderr, "Failed to fork: %s\n", strerror(errno));
        return 1;
    }

    if (pid == 0) {
        signal(SIGINT, SIG_DFL);
        signal(SIGTERM, SIG_DFL);
        signal(SIGHUP, SIG_DFL);
        signal(SIGQUIT, SIG_DFL);
        execv(child_argv[0], child_argv);
        fprintf(stderr, "Failed to exec %s: %s\n", child_argv[0], strerror(errno));
        _exit(127);
    }

    child_pid = pid;

    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = forward_signal;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;

    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGHUP, &sa, NULL);
    sigaction(SIGQUIT, &sa, NULL);

    int status = 0;
    while (waitpid(pid, &status, 0) == -1) {
        if (errno == EINTR) {
            continue;
        }
        fprintf(stderr, "waitpid failed: %s\n", strerror(errno));
        return 1;
    }

    if (WIFEXITED(status)) {
        return WEXITSTATUS(status);
    }

    if (WIFSIGNALED(status)) {
        return 128 + WTERMSIG(status);
    }

    return 1;
}
