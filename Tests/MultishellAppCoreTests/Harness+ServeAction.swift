@testable import MultishellAppCore
@testable import MultishellCore

extension Harness {
  /// A harness whose project has the one action `ProjectAction.serve`.
  static func withServeAction() -> Harness {
    let harness = Harness()
    harness.model.setSettings(ProjectSettings(actions: [.serve]), for: harness.project)
    return harness
  }
}
