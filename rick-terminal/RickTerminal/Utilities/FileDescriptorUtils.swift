import Foundation

/// Utilities for managing file descriptor inheritance in child processes
enum FileDescriptorUtils {

    /// Set FD_CLOEXEC on all open file descriptors except stdin/stdout/stderr
    /// This prevents sockets and other FDs from being inherited by child processes
    /// Call this before spawning child processes (like shell sessions)
    static func markAllFileDescriptorsCloseOnExec() {
        // Get the maximum number of file descriptors
        var rlimit = rlimit()
        getrlimit(RLIMIT_NOFILE, &rlimit)
        let maxFd = Int(rlimit.rlim_cur)

        // Iterate through all possible FDs (skip 0, 1, 2 = stdin, stdout, stderr)
        for fd in 3..<maxFd {
            // Get current flags
            let flags = fcntl(Int32(fd), F_GETFD)

            // If fcntl returns -1, the FD is not open - skip it
            guard flags != -1 else { continue }

            // Set FD_CLOEXEC flag
            _ = fcntl(Int32(fd), F_SETFD, flags | FD_CLOEXEC)
        }

        NSLog("[FileDescriptorUtils] Marked FDs 3-%d as close-on-exec", maxFd - 1)
    }

    /// Check if a specific file descriptor has FD_CLOEXEC set
    static func hasCloseOnExec(fd: Int32) -> Bool {
        let flags = fcntl(fd, F_GETFD)
        return flags != -1 && (flags & FD_CLOEXEC) != 0
    }

    /// Get count of open file descriptors (for debugging)
    static func countOpenFileDescriptors() -> Int {
        var rlimit = rlimit()
        getrlimit(RLIMIT_NOFILE, &rlimit)
        let maxFd = Int(rlimit.rlim_cur)

        var count = 0
        for fd in 0..<maxFd {
            if fcntl(Int32(fd), F_GETFD) != -1 {
                count += 1
            }
        }
        return count
    }
}
