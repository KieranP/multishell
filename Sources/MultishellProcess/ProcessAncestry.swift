import Foundation

/// Who ran us: the nearest ancestor that is not a shell, so a hook's helper
/// reports the agent rather than the `sh -c` layers between.
public enum ProcessAncestry {
  /// Shells an agent might run a hook through. `login` is what a terminal
  /// puts under itself.
  public static let shells: Set<String> = [
    "sh", "bash", "zsh", "dash", "fish", "ksh", "mksh", "tcsh", "csh", "login",
  ]

  public static func reportingProcess(startingAt pid: Int32 = getppid()) -> Int32 {
    var current = pid
    for _ in 0..<16 {
      guard let name = name(of: current), shells.contains(name),
        let parent = parent(of: current), parent > 1
      else { return current }
      current = parent
    }
    return current
  }

  /// Whether the process has left the table. Only ESRCH means gone; EPERM
  /// is another user's live process.
  public static func isGone(_ pid: Int32) -> Bool {
    guard pid > 0 else { return true }
    return kill(pid, 0) != 0 && errno == ESRCH
  }

  public static func parent(of pid: Int32) -> Int32? {
    #if os(Linux)
      guard let stat = procStat(pid) else { return nil }
      // "pid (comm) state ppid ...", and comm may hold spaces or parens.
      guard let close = stat.lastIndex(of: ")") else { return nil }
      let fields = stat[stat.index(after: close)...].split(separator: " ")
      return fields.count > 1 ? Int32(fields[1]) : nil
    #else
      guard let info = kinfo(pid) else { return nil }
      return info.kp_eproc.e_ppid
    #endif
  }

  /// The executable's name as the kernel keeps it: 16 characters on
  /// Darwin, 15 on Linux, which is enough to tell a shell from an agent.
  public static func name(of pid: Int32) -> String? {
    #if os(Linux)
      let path = "/proc/\(pid)/comm"
      return try? String(contentsOfFile: path, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    #else
      guard var info = kinfo(pid) else { return nil }
      return withUnsafePointer(to: &info.kp_proc.p_comm) { pointer in
        pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) {
          String(cString: $0)
        }
      }
    #endif
  }

  #if os(Linux)
    private static func procStat(_ pid: Int32) -> String? {
      try? String(contentsOfFile: "/proc/\(pid)/stat", encoding: .utf8)
    }
  #else
    private static func kinfo(_ pid: Int32) -> kinfo_proc? {
      var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
      var info = kinfo_proc()
      var size = MemoryLayout<kinfo_proc>.size
      guard sysctl(&name, UInt32(name.count), &info, &size, nil, 0) == 0, size > 0 else {
        return nil
      }
      return info
    }
  #endif
}
