import AppKit
import MultishellAppCore
import MultishellCore

extension GhosttyTerminalHost: TerminalSurfaceHost {}
extension SwiftTermTerminalHost: TerminalSurfaceHost {}

extension TerminalEngine {
  /// The Mac's engine for a kind, handed to `MultiEngineHost` as its factory.
  @MainActor
  func makeHost() -> any TerminalSurfaceHost<NSView> {
    switch self {
    case .ghostty: GhosttyTerminalHost()
    case .swiftTerm: SwiftTermTerminalHost()
    }
  }
}
