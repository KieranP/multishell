import GhosttyKit

extension GhosttySurfaceView {
  /// Bytes its screens, scrollback and images hold, under libghostty's terminal lock;
  /// `nil` once freed. The call is our patch 0006 (dependencies.md).
  var terminalMemory: UInt64? {
    guard let surface else { return nil }
    return ghostty_surface_memory_usage(surface)
  }
}
