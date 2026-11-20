import MultishellCore

/// The All changes tab's arrows across its files: each change of each file is
/// one stop, ordered by where it starts in the list.
public struct AllChangesSteps: Sendable {
  public struct Placed: Sendable {
    let stop: AllChangesFileRow
    /// Where it starts in the list.
    let top: Double

    public init(stop: AllChangesFileRow, top: Double) {
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
  public func stop(
    _ direction: CycleDirection,
    from origin: Double,
    isBoxed: Bool,
  ) -> AllChangesFileRow? {
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
