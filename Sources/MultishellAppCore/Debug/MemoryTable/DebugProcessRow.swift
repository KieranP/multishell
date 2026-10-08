import MultishellProcess

/// One process in an expanded row of the Memory by tab table, at its depth
/// in the tree of who started whom.
public struct DebugProcessRow: Sendable, Equatable, Identifiable, DebugSelfAndTotalMemory {
  public let process: ProcessUsage
  /// 0 for a process whose parent is not in the list, such as a pane's shell.
  public let depth: Int
  /// The process and everything under it.
  public let totalMemory: UInt64

  public var selfMemory: UInt64 { process.footprint }

  public var id: Int32 { process.pid }

  /// Depth first, siblings by what their whole tree holds, so a small shell running a
  /// large agent leads. A process whose parent is missing, or in a pid loop, starts a tree.
  static func rows(of processes: [ProcessUsage]) -> [DebugProcessRow] {
    let childrenByParent = Dictionary(grouping: processes, by: \.parentPID)
    var treeMemories: [Int32: UInt64] = [:]

    func treeMemory(of process: ProcessUsage, visiting: inout Set<Int32>) -> UInt64 {
      if let known = treeMemories[process.pid] { return known }
      guard visiting.insert(process.pid).inserted else { return 0 }
      let total = (childrenByParent[process.pid] ?? []).reduce(process.footprint) {
        $0 + treeMemory(of: $1, visiting: &visiting)
      }
      treeMemories[process.pid] = total
      return total
    }

    func heaviestTreeFirst(_ siblings: [ProcessUsage]) -> [ProcessUsage] {
      var visiting: Set<Int32> = []
      let weighed = siblings.map { ($0, treeMemory(of: $0, visiting: &visiting)) }
      return weighed.sorted { ($0.1, $1.0.pid) > ($1.1, $0.0.pid) }.map(\.0)
    }

    let tree = processes.depthFirstTree(
      id: \.pid, parentID: \.parentPID, siblingOrder: heaviestTreeFirst,
      leftoverOrder: { $0.heaviestFirst() })
    return tree.map { process, depth in
      var visiting: Set<Int32> = []
      return DebugProcessRow(
        process: process, depth: depth, totalMemory: treeMemory(of: process, visiting: &visiting))
    }
  }
}
