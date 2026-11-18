import MultishellCore

/// The All changes tab's arrows across its files: each change of each file is
/// one stop, ordered by where it starts in the list.
public struct AllChangesSteps: Sendable {
  /// A change: its file's section and its first row in that file's view.
  public struct Stop: Equatable, Sendable {
    public let section: Int
    public let row: Int

    public init(section: Int, row: Int) {
      self.section = section
      self.row = row
    }
  }

  public struct Placed: Sendable {
    public let stop: Stop
    /// Where it starts in the list.
    public let top: Double

    public init(stop: Stop, top: Double) {
      self.stop = stop
      self.top = top
    }
  }

  private let placed: [Placed]

  public init(_ placed: [Placed]) {
    self.placed = placed.sorted { $0.top < $1.top }
  }

  /// The stop a step lands on from `origin`: the boxed stop's top, or with
  /// nothing boxed the clip's top, where a stop at it is the first step.
  public func stop(_ direction: CycleDirection, from origin: Double, isBoxed: Bool) -> Stop? {
    switch direction {
    case .next:
      placed.first { isBoxed ? $0.top > origin : $0.top >= origin }?.stop

    case .previous:
      placed.last { $0.top < origin }?.stop
    }
  }

  public func changeSteps(from origin: Double, isBoxed: Bool) -> ChangeSteps {
    ChangeSteps(
      hasNext: stop(.next, from: origin, isBoxed: isBoxed) != nil,
      hasPrevious: stop(.previous, from: origin, isBoxed: isBoxed) != nil,
    )
  }
}
