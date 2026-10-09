import Darwin

/// The kernel's whole process table read once, so a scan asks it nothing per
/// pid but the usage: `proc_listchildpids` walks the table on every call.
struct ProcessTableSnapshot {
  private let recordsByPID: [Int32: kinfo_proc]
  private let childrenByParent: [Int32: [Int32]]

  init(records: [kinfo_proc]) {
    recordsByPID = Dictionary(
      records.map { ($0.kp_proc.p_pid, $0) },
      uniquingKeysWith: { first, _ in first },
    )
    childrenByParent = Dictionary(grouping: records) { $0.kp_eproc.e_ppid }
      .mapValues { $0.map(\.kp_proc.p_pid) }
  }

  static func take() -> Self {
    Self(records: KernelProcessTable.allRecords())
  }

  func children(of pid: Int32) -> [Int32] { childrenByParent[pid] ?? [] }

  func name(of pid: Int32) -> String? { recordsByPID[pid].map(KernelProcessTable.name(in:)) }

  func terminalDevice(of pid: Int32) -> Int32? {
    recordsByPID[pid].flatMap(KernelProcessTable.terminalDevice(in:))
  }
}
