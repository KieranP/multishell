/// The first word of each command that drives the app, and the topic its
/// usage errors and `help` name.
enum ControlCommand: String, CaseIterable {
  case board
  case config
  case debug
  case files
  case info
  case open
  case panes
  case projects
  case quit
  case sidebar
  case tabs
  case userInterface = "ui"
  case window
  case worktrees
}
