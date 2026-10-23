import MultishellCore

/// Whether a step either way has a change to land on, for the bar to grey out
/// an arrow with none.
public struct ChangeSteps: Equatable, Sendable {
  static let neitherWay = Self(hasNext: false, hasPrevious: false)

  let hasNext: Bool
  let hasPrevious: Bool

  public func allows(_ direction: CycleDirection) -> Bool {
    direction == .next ? hasNext : hasPrevious
  }
}
