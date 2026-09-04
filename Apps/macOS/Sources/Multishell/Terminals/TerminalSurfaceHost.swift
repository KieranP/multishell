import AppKit
import MultishellCore

/// A `TerminalHost` whose sessions each have a view to put on screen.
///
/// The view requirement lives here rather than in the core, which must stay
/// free of AppKit for the Linux and Windows frontends. Layout is the caller's
/// job: a host hands out one view per session and never decides what is
/// visible, which is what lets a tab show several at once.
@MainActor
protocol TerminalSurfaceHost: TerminalHost {
  func view(for id: TerminalSession.ID) -> NSView?
}

extension GhosttyTerminalHost: TerminalSurfaceHost {}
extension SwiftTermTerminalHost: TerminalSurfaceHost {}

extension TerminalEngine {
  @MainActor
  func makeHost() -> any TerminalSurfaceHost {
    switch self {
    case .ghostty: GhosttyTerminalHost()
    case .swiftTerm: SwiftTermTerminalHost()
    }
  }
}
