import Foundation

/// Whether an installed file holds what this build writes. Nothing rewrites
/// one unasked, the row offering Update instead; see Docs/design/agents.md.
extension AgentHookIntegration {
  public enum InstallState: Sendable, Equatable {
    case absent, stale, current
  }

  /// Whether any hook of ours is there, and whether it is current, from one
  /// read of the file, for a status that asks both of every agent on the main actor.
  public func installState(
    in file: URL? = nil, helper: String = AgentHookCatalogue.helperReference
  ) -> InstallState {
    let file = file ?? self.file
    if format.isOursAlone {
      guard let contents = ourFileContents(file) else { return .absent }
      return contents == snippet(helper: helper) ? .current : .stale
    }
    // Any of ours, not one under every event: an older build's file lacks the
    // events added since, and that is the update this is here to offer.
    guard let settings = try? AgentHookFile.read(file), holdsAnyOfOurHooks(settings) else {
      return .absent
    }
    return isCurrent(in: settings, helper: helper) ? .current : .stale
  }

  /// Our groups under each event are exactly the one this build writes, and
  /// none is under an event it no longer asks for.
  func isCurrent(in settings: [String: Any], helper: String) -> Bool {
    guard let hooks = hooksSection(settings),
      let wanted = hooksObject(helper: helper)["hooks"] as? [String: Any]
    else { return false }
    // Rendered, as a file's numbers are read as marked literals.
    return Set(hooks.keys).union(wanted.keys).allSatisfy { event in
      let installed = ((hooks[event] as? [[String: Any]]) ?? []).filter(holdsOurHook)
      let expected = (wanted[event] as? [[String: Any]]) ?? []
      return AgentHookFile.render(["hooks": installed])
        == AgentHookFile.render(["hooks": expected])
    }
  }
}
