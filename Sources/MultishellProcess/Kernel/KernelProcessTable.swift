import Foundation

/// What the kernel's process table says about one pid.
public enum KernelProcessTable {
  /// Whether the process has left the table. Only ESRCH means gone; EPERM
  /// is another user's live process.
  public static func isGone(_ pid: Int32) -> Bool {
    guard pid > 0 else { return true }
    return kill(pid, 0) != 0 && errno == ESRCH
  }

  static func children(of pid: Int32) -> [Int32] {
    var capacity = 64
    while true {
      var pids = [Int32](repeating: 0, count: capacity)
      let count = pids.withUnsafeMutableBytes {
        proc_listchildpids(pid, $0.baseAddress, Int32($0.count))
      }
      guard count > 0 else { return [] }
      if count < capacity { return Array(pids.prefix(Int(count))) }
      capacity *= 2
    }
  }

  /// The arguments joined by spaces, or `nil` for a process not ours to read.
  static func commandLine(of pid: Int32) -> String? {
    // KERN_PROCARGS2 is argc, then the executable path and the arguments,
    // each NUL-terminated; the environment follows and is left unread.
    var name: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
    var size = 0
    guard sysctl(&name, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else {
      return nil
    }
    var buffer = [UInt8](repeating: 0, count: size)
    guard sysctl(&name, 3, &buffer, &size, nil, 0) == 0 else { return nil }
    let argc = buffer.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
    let afterCount = buffer[MemoryLayout<Int32>.size..<size]
    guard let pathEnd = afterCount.firstIndex(of: 0),
      let argumentsStart = afterCount[pathEnd...].firstIndex(where: { $0 != 0 })
    else { return nil }
    let words = afterCount[argumentsStart...]
      .split(separator: 0, maxSplits: Int(argc), omittingEmptySubsequences: false)
      .prefix(Int(argc))
    return words.map { String(decoding: $0, as: UTF8.self) }.joined(separator: " ")
  }

  static func parent(of pid: Int32) -> Int32? {
    guard let info = record(of: pid) else { return nil }
    return info.kp_eproc.e_ppid
  }

  /// The executable's name as the kernel keeps it: 16 characters, which is
  /// enough to tell a shell from an agent.
  static func name(of pid: Int32) -> String? {
    guard var info = record(of: pid) else { return nil }
    return withUnsafePointer(to: &info.kp_proc.p_comm) { pointer in
      pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) {
        String(cString: $0)
      }
    }
  }

  static func record(of pid: Int32) -> kinfo_proc? {
    var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.size
    guard sysctl(&name, UInt32(name.count), &info, &size, nil, 0) == 0, size > 0 else {
      return nil
    }
    return info
  }
}
