import Foundation

/// Raises the soft limit on open file descriptors to the hard limit.
///
/// launchd starts a GUI app with 256. Each watched worktree directory holds
/// one, each live shell a pty and its engine's pipes, and each concurrent
/// `git status` six. The hard limit is unlimited; `OPEN_MAX` is the most the
/// kernel accepts for the soft one. libdispatch raises it too, once, to a
/// couple of thousand when the first file source is made; this makes the
/// floor deterministic and higher.
enum DescriptorLimit {
  /// Never lowers. Returns the soft limit in force afterwards.
  @discardableResult
  static func raise() -> Int {
    var limit = rlimit()
    guard getrlimit(RLIMIT_NOFILE, &limit) == 0 else { return -1 }
    let ceiling = min(limit.rlim_max, rlim_t(OPEN_MAX))
    if limit.rlim_cur < ceiling {
      limit.rlim_cur = ceiling
      setrlimit(RLIMIT_NOFILE, &limit)
      getrlimit(RLIMIT_NOFILE, &limit)
    }
    // `RLIM_INFINITY` is `UInt64.max`; a plain `Int(_:)` would trap on it.
    return Int(clamping: limit.rlim_cur)
  }
}
