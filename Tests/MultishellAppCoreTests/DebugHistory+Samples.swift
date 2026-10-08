@testable import MultishellAppCore

extension DebugHistory {
  static func of(_ samples: [DebugSample]) -> DebugHistory {
    var history = DebugHistory()
    for sample in samples { history.append(sample) }
    return history
  }
}
