import GhosttyKit

/// The process behind the pane, as libghostty reads it off the pty.
extension GhosttySurfaceView {
  /// The pty's path, as `/dev/ttys004`; `nil` before the shell has one.
  var terminalPath: String? {
    guard let surface else { return nil }
    let name = ghostty_surface_tty_name(surface)
    defer { ghostty_string_free(name) }
    guard let bytes = name.ptr, name.len > 0 else { return nil }
    return String(
      decoding: UnsafeRawBufferPointer(start: bytes, count: Int(name.len)),
      as: UTF8.self,
    )
  }

  /// libghostty answers 0 where the pty has no foreground group.
  var foregroundPID: Int32? {
    guard let surface else { return nil }
    let pid = ghostty_surface_foreground_pid(surface)
    return pid == 0 ? nil : Int32(exactly: pid)
  }
}
