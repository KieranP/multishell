import MultishellCore

/// A `TerminalHost` whose sessions each have a view to put on screen, the
/// platform fixing `Surface` once. Layout is the caller's job.
@MainActor
public protocol TerminalSurfaceHost<Surface>: TerminalHost {
  associatedtype Surface
  func view(for id: TerminalSession.ID) -> Surface?
}
