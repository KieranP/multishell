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

  /// The stop a step lands on from `origin`, where a stop at the clip's top is
  /// the first step with nothing boxed.
  public func stop(
    _ direction: CycleDirection,
    from origin: AllChangesStepOrigin,
  )
    -> AllChangesFileRow?
  {
    switch direction {
    case .next:
      placed.first { origin.isBoxed ? $0.top > origin.top : $0.top >= origin.top }?.stop

    case .previous:
      placed.last { $0.top < origin.top }?.stop
    }
  }

  public func changeSteps(from origin: AllChangesStepOrigin) -> ChangeSteps {
    ChangeSteps(
      hasNext: stop(.next, from: origin) != nil,
      hasPrevious: stop(.previous, from: origin) != nil,
    )
  }
}
