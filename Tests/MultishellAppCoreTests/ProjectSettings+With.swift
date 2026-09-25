import MultishellCore

extension ProjectSettings {
  func with(_ change: (inout ProjectSettings) -> Void) -> ProjectSettings {
    var updated = self
    change(&updated)
    return updated
  }
}
