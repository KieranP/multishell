import MultishellCore

/// A `TerminalHost` whose sessions each have a view to put on screen.
///
/// `Surface` is the platform's view type (`NSView` on the Mac), so the core
/// stays free of any GUI framework and each frontend fixes the type once.
/// Layout is the caller's job: a host hands out one view per session and
/// never decides what is visible, which is what lets a tab show several at
/// once.
@MainActor
public protocol TerminalSurfaceHost<Surface>: TerminalHost {
  associatedtype Surface
  func view(for id: TerminalSession.ID) -> Surface?
}
