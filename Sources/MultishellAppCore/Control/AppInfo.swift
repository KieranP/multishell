/// What `multishell info` prints: which copy answered, for `footprint` and its
/// state file, and what is up on screen that a script would stall behind.
struct AppInfo: Encodable, Equatable {
  let pid: Int32
  let stateFile: String
  let socket: String
  let areDebugToolsEnabled: Bool
  let windows: [PlatformWindow]
  /// Topmost first.
  let presented: [PresentationEntry]
}
