/// Which kind a tab the command line prints is, by the word it prints.
enum TabKind: String, Encodable, Equatable {
  case file
  case terminal
}
