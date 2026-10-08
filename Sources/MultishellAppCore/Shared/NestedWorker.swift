/// A worker in the order the chip's list draws it, under its parent; see
/// Docs/design/agents.md.
public struct NestedWorker: Identifiable, Equatable, Sendable {
  public let worker: Worker
  /// How many parents it is under, `0` for one the agent launched itself.
  public let depth: Int

  public var id: String { worker.id }
}
