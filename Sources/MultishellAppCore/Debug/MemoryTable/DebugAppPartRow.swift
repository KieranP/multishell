/// A nested row under the expanded Multishell row: one part of the app's own
/// footprint, its tabs' terminals left out as the row leaves them out.
public struct DebugAppPartRow: Sendable, Equatable, Identifiable, DebugSelfAndTotalMemory {
  public enum Part: String, Sendable, Hashable {
    case gpu
    case heapInUse
    case fileTabs
    case freedHeap
    case librariesAndOther
  }

  let part: Part
  public let selfMemory: UInt64
  public let totalMemory: UInt64
  /// 1 for the file tabs where the heap in use, which holds their text, is above them.
  public let indentLevel: Int
  let fileTabCount: Int

  public var id: Part { part }

  init(
    part: Part,
    selfMemory: UInt64,
    totalMemory: UInt64? = nil,
    indentLevel: Int = 0,
    fileTabCount: Int = 0,
  ) {
    self.part = part
    self.selfMemory = selfMemory
    self.totalMemory = totalMemory ?? selfMemory
    self.indentLevel = indentLevel
    self.fileTabCount = fileTabCount
  }
}
