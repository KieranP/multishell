import Foundation

/// Raises the soft limit on open file descriptors as far as the kernel
/// allows.
///
/// launchd starts a Mac GUI app with 256 and a Linux desktop session gives
/// 1024. Each watched worktree directory holds one, each live shell a pty
/// and its engine's pipes, and each concurrent `git status` six. On Darwin
/// `OPEN_MAX` is the most the kernel accepts for the soft limit however high
/// the hard one is; on Linux the hard limit is the ceiling. libdispatch
/// raises it too, once, to a couple of thousand when the first file source
/// is made; this makes the floor deterministic and higher.
public enum DescriptorLimit {
  /// Never lowers. Returns the soft limit in force afterwards.
  @discardableResult
  public static func raise() -> Int {
    var limit = rlimit()
    guard getrlimit(resource, &limit) == 0 else { return -1 }
    let ceiling = ceiling(of: limit)
    if limit.rlim_cur < ceiling {
      limit.rlim_cur = ceiling
      setrlimit(resource, &limit)
      getrlimit(resource, &limit)
    }
    // `RLIM_INFINITY` is the type's maximum; a plain `Int(_:)` would trap.
    return Int(clamping: limit.rlim_cur)
  }

  /// What the soft limit can be raised to.
  static func ceiling(of limit: rlimit) -> rlim_t {
    #if os(Linux)
      limit.rlim_max
    #else
      min(limit.rlim_max, rlim_t(OPEN_MAX))
    #endif
  }

  #if os(Linux)
    // Glibc declares the resource as an enum and the functions take its
    // typedef, so the constant is converted through its raw value.
    static let resource = __rlimit_resource_t(RLIMIT_NOFILE.rawValue)
  #else
    static let resource = RLIMIT_NOFILE
  #endif
}
