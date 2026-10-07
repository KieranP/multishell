/// One point of a strip as fractions of its height: the app's part, and the
/// whole above it. The two are equal for a metric not split by owner.
public struct DebugStripPoint: Sendable, Equatable {
  public let app: Double
  public let total: Double
}
