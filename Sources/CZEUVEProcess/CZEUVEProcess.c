#include "CZEUVEProcess.h"

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <spawn.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#if defined(__APPLE__)
#include <sys/param.h>
#endif

extern char **environ;

static void zeuve_close_if_valid(int fd) {
    if (fd >= 0) {
        close(fd);
    }
}

int zeuve_spawn_process(
    const char *path,
    char *const argv[],
    char *const envp[],
    const char *working_directory,
    pid_t *child_pid,
    int *stdout_fd,
    int *stderr_fd
) {
    if (!path || !argv || !child_pid || !stdout_fd || !stderr_fd) {
        return EINVAL;
    }

    int out_pipe[2] = {-1, -1};
    int err_pipe[2] = {-1, -1};
    if (pipe(out_pipe) != 0) {
        return errno;
    }
    if (pipe(err_pipe) != 0) {
        int error = errno;
        zeuve_close_if_valid(out_pipe[0]);
        zeuve_close_if_valid(out_pipe[1]);
        return error;
    }

    fcntl(out_pipe[0], F_SETFD, FD_CLOEXEC);
    fcntl(err_pipe[0], F_SETFD, FD_CLOEXEC);

    posix_spawn_file_actions_t actions;
    posix_spawnattr_t attributes;
    int result = posix_spawn_file_actions_init(&actions);
    if (result != 0) goto cleanup_pipes;
    result = posix_spawnattr_init(&attributes);
    if (result != 0) goto cleanup_actions;

    result = posix_spawn_file_actions_adddup2(&actions, out_pipe[1], STDOUT_FILENO);
    if (result != 0) goto cleanup_attributes;
    result = posix_spawn_file_actions_adddup2(&actions, err_pipe[1], STDERR_FILENO);
    if (result != 0) goto cleanup_attributes;
    result = posix_spawn_file_actions_addclose(&actions, out_pipe[0]);
    if (result != 0) goto cleanup_attributes;
    result = posix_spawn_file_actions_addclose(&actions, err_pipe[0]);
    if (result != 0) goto cleanup_attributes;
    result = posix_spawn_file_actions_addclose(&actions, out_pipe[1]);
    if (result != 0) goto cleanup_attributes;
    result = posix_spawn_file_actions_addclose(&actions, err_pipe[1]);
    if (result != 0) goto cleanup_attributes;

#if defined(__APPLE__)
    if (working_directory && working_directory[0] != '\0') {
        result = posix_spawn_file_actions_addchdir_np(&actions, working_directory);
        if (result != 0) goto cleanup_attributes;
    }
#else
    (void)working_directory;
#endif

    short flags = POSIX_SPAWN_SETPGROUP;
    result = posix_spawnattr_setflags(&attributes, flags);
    if (result != 0) goto cleanup_attributes;
    result = posix_spawnattr_setpgroup(&attributes, 0);
    if (result != 0) goto cleanup_attributes;

    pid_t pid = 0;
    result = posix_spawn(&pid, path, &actions, &attributes, argv, envp ? envp : environ);
    if (result != 0) goto cleanup_attributes;

    close(out_pipe[1]);
    close(err_pipe[1]);
    *child_pid = pid;
    *stdout_fd = out_pipe[0];
    *stderr_fd = err_pipe[0];

    posix_spawnattr_destroy(&attributes);
    posix_spawn_file_actions_destroy(&actions);
    return 0;

cleanup_attributes:
    posix_spawnattr_destroy(&attributes);
cleanup_actions:
    posix_spawn_file_actions_destroy(&actions);
cleanup_pipes:
    zeuve_close_if_valid(out_pipe[0]);
    zeuve_close_if_valid(out_pipe[1]);
    zeuve_close_if_valid(err_pipe[0]);
    zeuve_close_if_valid(err_pipe[1]);
    return result == 0 ? errno : result;
}

int zeuve_signal_process_group(pid_t child_pid, int signal_number) {
    if (child_pid <= 0) return EINVAL;
    if (kill(-child_pid, signal_number) == 0) return 0;
    return errno;
}

int zeuve_wait_process(pid_t child_pid, int timeout_ms, int *exit_status, int *termination_signal) {
    if (child_pid <= 0 || !exit_status || !termination_signal) return EINVAL;
    const long sleep_ns = 10 * 1000 * 1000;
    int elapsed = 0;

    while (1) {
        int status = 0;
        pid_t result = waitpid(child_pid, &status, WNOHANG);
        if (result == child_pid) {
            *exit_status = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
            *termination_signal = WIFSIGNALED(status) ? WTERMSIG(status) : 0;
            return 0;
        }
        if (result < 0) {
            if (errno == EINTR) continue;
            return errno;
        }
        if (timeout_ms >= 0 && elapsed >= timeout_ms) return ETIMEDOUT;
        struct timespec request = {0, sleep_ns};
        nanosleep(&request, NULL);
        elapsed += 10;
    }
}

int zeuve_process_group_exists(pid_t child_pid) {
    if (child_pid <= 0) return -1;
    if (kill(-child_pid, 0) == 0) return 1;
    if (errno == ESRCH) return 0;
    if (errno == EPERM) return 1;
    return -1;
}
