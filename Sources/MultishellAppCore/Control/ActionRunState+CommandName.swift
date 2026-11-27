/// `actions list`'s word for where an action's run is.
extension ActionRunState {
  var commandName: String {
    switch self {
    case .idle: "idle"
    case .running: "running"
    case .done: "done"
    case .failed: "failed"
    }
  }
}
