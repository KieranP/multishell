/// One point of a strip as fractions of its height: the app's own part, its terminals
/// above it, then the whole. A metric with fewer series repeats an edge.
public struct DebugStripPoint: Sendable, Equatable {
  public let app: Double
  public let appWithTerminals: Double
  public let total: Double
}
