import Foundation

/// Raises the soft descriptor limit as far as the kernel allows: launchd
/// starts a Mac GUI app with 256. Darwin caps it at `OPEN_MAX`.
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
    min(limit.rlim_max, rlim_t(OPEN_MAX))
  }

  static let resource = RLIMIT_NOFILE
}
