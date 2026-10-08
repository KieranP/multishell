import Foundation

@testable import MultishellCore

extension AgentHookIntegration {
  /// The suites' oracle: a hook of ours under every event. The app asks
  /// `installState`, which counts any of ours.
  func hasOurHookUnderEveryEvent(in settings: [String: Any]) -> Bool {
    // An agent with no events has no hooks in any file; without this every
    // settings object would satisfy an empty list.
    guard !events.isEmpty else { return false }
    return events.allSatisfy { holdsOurHook(under: $0, in: settings) }
  }

  func hasOurHookUnderEveryEvent(in file: URL? = nil) -> Bool {
    let file = file ?? self.file
    if format.isOursAlone { return ourFileContents(file) != nil }
    guard let settings = try? AgentHookFile.read(file) else { return false }
    return hasOurHookUnderEveryEvent(in: settings)
  }
}
