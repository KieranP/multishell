/// What `ui switcher` says where it lists nothing.
extension QuickSwitcherEmptyReason {
  var commandName: String {
    switch self {
    case .noMatch: "no-match"
    case .nothingToList: "nothing-to-list"
    case .readingFiles: "reading-files"
    }
  }
}
