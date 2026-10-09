/// What runs under a process, read from the kernel's table. The table is read
/// once a scan, then a call per process for its usage, so it runs off the main actor.
public enum ProcessTreeScan {
  public static func childTrees(of pid: Int32) -> [ProcessTree] {
    let table = ProcessTableSnapshot.take()
    return table.children(of: pid).map { child in
      ProcessTree(
        rootPID: child,
        terminalDevice: table.terminalDevice(of: child),
        processes: subtree(of: child, under: pid, in: table),
      )
    }
  }

  /// `nil` for a process that has gone or is not ours to read.
  public static func usage(of pid: Int32) -> ProcessUsage? {
    usage(
      of: pid,
      parentPID: KernelProcessTable.parent(of: pid) ?? 0,
      name: KernelProcessTable.name(of: pid),
    )
  }

  /// Each process with the parent it was found under, which the walk down
  /// knows without asking the kernel again.
  private static func subtree(
    of top: Int32,
    under parent: Int32,
    in table: ProcessTableSnapshot,
  ) -> [ProcessUsage] {
    var found: [ProcessUsage] = []
    var visited: Set<Int32> = []
    var pending = [(pid: top, parentPID: parent)]
    while let next = pending.popLast() {
      guard visited.insert(next.pid).inserted else { continue }
      if let usage = usage(of: next.pid, parentPID: next.parentPID, name: table.name(of: next.pid))
      {
        found.append(usage)
      }
      pending += table.children(of: next.pid).map { (pid: $0, parentPID: next.pid) }
    }
    return found
  }

  private static func usage(of pid: Int32, parentPID: Int32, name: String?) -> ProcessUsage? {
    guard let resources = KernelResourceUsage.of(pid) else { return nil }
    let name = name ?? String(pid)
    let label = ProcessLabel.of(
      name: name,
      arguments: KernelProcessTable.arguments(of: pid)?.arguments,
    )
    return ProcessUsage(
      pid: pid,
      parentPID: parentPID,
      name: label,
      footprint: resources.footprint,
      cpuTime: resources.cpuTime,
    )
  }
}
