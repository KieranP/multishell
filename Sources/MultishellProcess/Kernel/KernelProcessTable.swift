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
    arguments(of: pid)?.arguments.joined(separator: " ")
  }

  /// `nil` for a process not ours to read.
  static func arguments(of pid: Int32) -> ProcessArguments? {
    var name: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
    var size = 0
    guard sysctl(&name, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else {
      return nil
    }
    var buffer = [UInt8](repeating: 0, count: size)
    guard sysctl(&name, 3, &buffer, &size, nil, 0) == 0 else { return nil }
    return ProcessArguments(procArgs: buffer.prefix(size))
  }

  /// `NODEV`, a macro Swift does not import.
  static let noDevice: Int32 = -1

  /// The controlling terminal's device number, `nil` for a process with none.
  static func terminalDevice(of pid: Int32) -> Int32? {
    record(of: pid).flatMap(terminalDevice(in:))
  }

  static func terminalDevice(in record: kinfo_proc) -> Int32? {
    record.kp_eproc.e_tdev == noDevice ? nil : record.kp_eproc.e_tdev
  }

  static func parent(of pid: Int32) -> Int32? {
    guard let info = record(of: pid) else { return nil }
    return info.kp_eproc.e_ppid
  }

  /// The executable's name as the kernel keeps it: 16 characters, which is
  /// enough to tell a shell from an agent.
  static func name(of pid: Int32) -> String? {
    record(of: pid).map(name(in:))
  }

  static func name(in record: kinfo_proc) -> String {
    var record = record
    return withUnsafePointer(to: &record.kp_proc.p_comm) { pointer in
      pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) {
        String(cString: $0)
      }
    }
  }

  /// Every process in the table, read in one call; empty where the kernel
  /// would not say. Retried where the table outgrew the buffer meanwhile.
  static func allRecords() -> [kinfo_proc] {
    var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
    let stride = MemoryLayout<kinfo_proc>.stride
    for _ in 0..<3 {
      var size = 0
      guard sysctl(&name, UInt32(name.count), nil, &size, nil, 0) == 0 else { return [] }
      var records = [kinfo_proc](repeating: kinfo_proc(), count: size / stride + 16)
      size = records.count * stride
      let read = records.withUnsafeMutableBytes {
        sysctl(&name, UInt32(name.count), $0.baseAddress, &size, nil, 0)
      }
      if read == 0 { return Array(records.prefix(size / stride)) }
      guard errno == ENOMEM else { return [] }
    }
    return []
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
