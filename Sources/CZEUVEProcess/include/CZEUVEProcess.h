#ifndef CZEUVE_PROCESS_H
#define CZEUVE_PROCESS_H

#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 Spawns an executable without a shell, in a new process group whose ID is the child PID.
 stdout and stderr are connected to separate pipes. Returns 0 on success or a POSIX error code.
 */
int zeuve_spawn_process(
    const char *path,
    char *const argv[],
    char *const envp[],
    const char *working_directory,
    pid_t *child_pid,
    int *stdout_fd,
    int *stderr_fd
);

/** Sends a signal to the complete process group created by zeuve_spawn_process. */
int zeuve_signal_process_group(pid_t child_pid, int signal_number);

/** Waits for the child. timeout_ms < 0 means no timeout. Returns 0 when reaped, ETIMEDOUT on timeout. */
int zeuve_wait_process(pid_t child_pid, int timeout_ms, int *exit_status, int *termination_signal);

/** Returns 1 if the process group still exists, 0 if not, or -1 on unexpected error. */
int zeuve_process_group_exists(pid_t child_pid);

#ifdef __cplusplus
}
#endif

#endif
