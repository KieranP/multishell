import MultishellCore

/// The shape a state's dot takes, so no state is told apart by colour alone:
/// waiting's blue is the selection's too. See Docs/design/appearance/window-chrome.md.
public enum StateDotKind: Hashable, Sendable {
  case filled
  case hollowRing
  /// An arc of the ring going round a faint track, still under Reduce Motion.
  case orbitingArc
  /// A ring round a centre dot, pulsing where motion is allowed.
  case ringAroundDot
  case square

  public init(_ state: SessionState) {
    switch state {
    case .attention: self = .ringAroundDot
    case .done: self = .filled
    case .failed: self = .square
    case .idle: self = .hollowRing
    case .running: self = .orbitingArc
    }
  }
}
