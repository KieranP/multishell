// Declared bottom to top, the order a split strip stacks its bands in.
// swiftlint:disable sorted_enum_cases
/// An edge a strip's band is drawn between, read off a point.
public enum DebugStripBoundary: Sendable {
  case baseline
  case app
  case appWithTerminals
  case total

  func fraction(of point: DebugStripPoint) -> Double {
    switch self {
    case .baseline: 0
    case .app: point.app
    case .appWithTerminals: point.appWithTerminals
    case .total: point.total
    }
  }
}
// swiftlint:enable sorted_enum_cases
